// sherpa-tts —— 用 sherpa-onnx 的 VITS/MeloTTS 中文模型把一句话合成成 wav。
//
// 用法：sherpa-tts <model-dir> <text> <out.wav>
//   model-dir 里需要有 model.int8.onnx（或 model.onnx）、tokens.txt、lexicon.txt。
//
// 为什么先做命令行工具而不是直接接进 App：和 llama 那次一样，先证明
// 「引擎能在这台机器上跑、多久出一句话、音质能不能听」，再决定怎么塞进产品。
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

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
        fprintf(stderr, "usage: %s <model-dir> <text> <out.wav>\n", argv[0]);
        return 1;
    }
    const char *dir = argv[1];
    const char *text = argv[2];
    const char *out = argv[3];

    char model[1024], lexicon[1024], tokens[1024], dict_dir[1024], date_fst[1024], number_fst[1024];
    snprintf(model, sizeof(model), "%s/model.int8.onnx", dir);
    snprintf(lexicon, sizeof(lexicon), "%s/lexicon.txt", dir);
    snprintf(tokens, sizeof(tokens), "%s/tokens.txt", dir);
    snprintf(date_fst, sizeof(date_fst), "%s/date.fst", dir);
    snprintf(number_fst, sizeof(number_fst), "%s/number.fst", dir);
    snprintf(dict_dir, sizeof(dict_dir), "%s", dir);

    SherpaOnnxOfflineTtsConfig config;
    memset(&config, 0, sizeof(config));
    config.model.vits.model = model;
    config.model.vits.lexicon = lexicon;
    config.model.vits.tokens = tokens;
    config.model.vits.data_dir = dict_dir;
    config.model.vits.dict_dir = dict_dir;
    config.model.vits.noise_scale = 0.667f;
    config.model.vits.noise_scale_w = 0.8f;
    config.model.vits.length_scale = 1.0f;
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
