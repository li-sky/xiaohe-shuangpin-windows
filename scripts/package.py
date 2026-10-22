"""Create a deterministic release archive, without user data or CI files."""
from pathlib import Path
import hashlib
import zipfile

root = Path(__file__).resolve().parent.parent
version = (root / 'VERSION').read_text().strip()
output = root / 'dist'
output.mkdir(exist_ok=True)
archive = output / f'xiaohe-shuangpin-{version}.zip'
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_STORED) as package:
    for name in ['README.md', 'VERSION', 'configure.ps1', 'xiaohe-shuangpin.reg', 'data/.gitkeep']:
        data = (root / name).read_bytes()
        # Git checkouts on Windows may convert line endings. Normalize text.
        if not name.endswith('.reg'):
            data = data.replace(b'\r\n', b'\n')
            if name.endswith('.ps1'):
                data = data.replace(b'\n', b'\r\n')
        info = zipfile.ZipInfo(name, date_time=(2020, 1, 1, 0, 0, 0))
        info.create_system = 3  # Keep ZIP metadata identical on Linux and Windows.
        info.external_attr = 0o644 << 16
        package.writestr(info, data)
hash_value = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix('.zip.sha256').write_text(f'{hash_value}  {archive.name}\n', encoding='ascii')
print(f'{hash_value}  {archive.name}')
