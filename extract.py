import gzip, io, lzma, os, sys, tarfile
sys.stdout.reconfigure(encoding="utf-8")
DIST = r"C:\Users\Jayden Wu\OneDrive\ドキュメント\deepseek-harness\default-workspace\DSHPet\dist_local"
deb = os.path.join(DIST, "com.jayden.dshpet_1.4.0_iphoneos-arm64.deb")
raw = open(deb, "rb").read()
pos, members = 8, {}
while pos < len(raw):
    hdr = raw[pos:pos+60]
    if len(hdr) < 60: break
    name = hdr[0:16].decode("utf-8", "replace").strip()
    size = int(hdr[48:58].decode("ascii").strip() or "0")
    members[name] = raw[pos+60:pos+60+size]
    pos += 60 + size + (size % 2)
key = [k for k in members if k.startswith("data.tar")][0]
dt = members[key]
print("member:", key, "first bytes:", dt[:6])
if dt[:2] == b"\x1f\x8b":
    decl = gzip.decompress(dt)
elif dt[:6] == b"\xfd7zXZ\x00":
    decl = lzma.decompress(dt)
else:
    decl = lzma.decompress(dt, format=lzma.FORMAT_ALONE)
tf = tarfile.open(fileobj=io.BytesIO(decl), mode="r:")
out_path = None
for m in tf.getmembers():
    n = m.name.lstrip("./")
    if n == "var/jb/usr/bin/dshpet-respring":
        data = tf.extractfile(m).read()
        out_path = os.path.join(DIST, "dshpet-respring")
        open(out_path, "wb").write(data)
        os.chmod(out_path, 0o755)
        print("extracted", out_path, len(data))
        break
print("ok" if out_path else "NOT FOUND")