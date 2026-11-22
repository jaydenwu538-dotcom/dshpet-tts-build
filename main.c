// sherpa-tts —— 用 sherpa-onnx 的 VITS / Piper 中文模型把一句话合成成 wav。
//
// 用法：sherpa-tts <model-dir> <text> <out.wav> [length-scale]
//   model-dir 里需要有 model.int8.onnx（或 model.onnx）、tokens.txt，
//   可选 lexicon.txt（x_low 类模型）或 espeak-ng-data/（medium 类模型）。
//   length-scale 可选，小于 1 语速更快、音更高；大于 1 更慢更沉稳。
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "sherpa-onnx/c-api/c-api.h"

static double now_seconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static void write_wav(const char *path, const float *samples, int32_t n, int32_t rate) {
    FILE *f = fopen(path, "wb");
    if (!f) {
        fprintf(stderr, "cannot open %s for write\n", path);
        return;
    }
    uint32_t data_bytes = (uint32_t)n * 2;
    uint32_t riff_size = 36 + data_bytes;
    uint32_t byte_rate = (uint32_t)rate * 2;
    uint16_t block_align = 2;

    fwrite("RIFF", 1, 4, f);
    fwrite(&riff_size, 4, 1, f);
    fwrite("WAVEfmt ", 1, 8, f);
    uint32_t fmt_size = 16;
    uint16_t audio_format = 1;  // PCM
    uint16_t channels = 1;
    fwrite(&fmt_size, 4, 1, f);
    fwrite(&audio_format, 2, 1, f);
    fwrite(&channels, 2, 1, f);
    fwrite(&rate, 4, 1, f);
    fwrite(&byte_rate, 4, 1, f);
    fwrite(&block_align, 2, 1, f);
    uint16_t bits = 16;
    fwrite(&bits, 2, 1, f);
    fwrite("data", 1, 4, f);
    fwrite(&data_bytes, 4, 1, f);

    for (int32_t i = 0; i < n; i++) {
        float v = samples[i];
        if (v > 1.0f) v = 1.0f;
        if (v < -1.0f) v = -1.0f;
        int16_t s = (int16_t)(v * 32767.0f);
        fwrite(&s, 2, 1, f);
    }
    fclose(f);
}

int main(int argc, char **argv) {
    if (argc < 4) {
        fprintf(stderr, "usage: %s <model-dir> <text> <out.wav> [length-scale]\n", argv[0]);
        return 1;
    }
    const char *dir = argv[1];
    const char *text = argv[2];
    const char *out = argv[3];

    char model[1024], lexicon[1024], tokens[1024], dict_dir[1024];
    char date_fst[1024], number_fst[1024], espeak_dir[1024];
    snprintf(model, sizeof(model), "%s/model.int8.onnx", dir);
    snprintf(lexicon, sizeof(lexicon), "%s/lexicon.txt", dir);
    snprintf(tokens, sizeof(tokens), "%s/tokens.txt", dir);
    snprintf(date_fst, sizeof(date_fst), "%s/date.fst", dir);
    snprintf(number_fst, sizeof(number_fst), "%s/number.fst", dir);
    snprintf(dict_dir, sizeof(dict_dir), "%s", dir);

    // Piper medium 这类模型用 espeak-ng 做音素化，数据放在 espeak-ng-data 子目录里。
    // 有就指过去；没有就沿用模型目录（x_low 那种带 lexicon.txt 的老模型）。
    snprintf(espeak_dir, sizeof(espeak_dir), "%s/espeak-ng-data", dir);
    if (access(espeak_dir, F_OK) == 0) {
        snprintf(dict_dir, sizeof(dict_dir), "%s", espeak_dir);
    }

    // 第 4 个可选参数：语速倍率。小于 1 会更快、音调更高，更接近「小宠物」的声音。
    float length_scale = 1.0f;
    if (argc >= 5) {
        float v = (float)atof(argv[4]);
        if (v > 0.3f && v < 3.0f) length_scale = v;
    }

    SherpaOnnxOfflineTtsConfig config;
    memset(&config, 0, sizeof(config));
    config.model.vits.model = model;
    // medium 这类模型不带 lexicon.txt（改用 espeak-ng），此时必须留空，
    // 否则 sherpa-onnx 的 Validate 会因为「lexicon 文件不存在」直接失败。
    config.model.vits.lexicon = (access(lexicon, F_OK) == 0) ? lexicon : NULL;
    config.model.vits.tokens = tokens;
    config.model.vits.data_dir = dict_dir;
    config.model.vits.dict_dir = dict_dir;
    config.model.vits.noise_scale = 0.667f;
    config.model.vits.noise_scale_w = 0.8f;
    config.model.vits.length_scale = length_scale;
    config.model.num_threads = 2;
    config.model.provider = "cpu";
    config.max_num_sentences = 1;
    config.rule_fsts = date_fst;   // 让「3月5日」这类读法正常
    config.rule_fars = number_fst;

    fprintf(stderr, "loading model from %s ...\n", dir);
    double t0 = now_seconds();
    const SherpaOnnxOfflineTts *tts = SherpaOnnxCreateOfflineTts(&config);
    if (!tts) {
        fprintf(stderr, "SherpaOnnxCreateOfflineTts failed\n");
        return 2;
    }
    double load_ms = (now_seconds() - t0) * 1000.0;

    fprintf(stderr, "generating: %s\n", text);
    double t1 = now_seconds();
    const SherpaOnnxGeneratedAudio *audio = SherpaOnnxOfflineTtsGenerate(tts, text, 0, 1.0f);
    double gen_ms = (now_seconds() - t1) * 1000.0;

    if (!audio || !audio->samples || audio->n <= 0) {
        fprintf(stderr, "generate failed\n");
        SherpaOnnxDestroyOfflineTts(tts);
        return 3;
    }

    double seconds = (double)audio->n / (double)audio->sample_rate;
    fprintf(stderr, "load=%.0f ms  gen=%.0f ms  samples=%d  rate=%d  audio=%.2f s  rtf=%.3f\n",
            load_ms, gen_ms, audio->n, audio->sample_rate, seconds, gen_ms / 1000.0 / seconds);

    write_wav(out, audio->samples, audio->n, audio->sample_rate);
    fprintf(stderr, "wrote %s\n", out);

    SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
    SherpaOnnxDestroyOfflineTts(tts);
    return 0;
}
