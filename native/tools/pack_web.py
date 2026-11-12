"""A telefonos kontroller (web/) becsomagolása web.zip-be, hogy az exe-be beágyazható legyen."""
import os, zipfile
root = os.path.join(os.path.dirname(__file__), '..')
src = os.path.join(root, 'web')
with zipfile.ZipFile(os.path.join(root, 'web.zip'), 'w', zipfile.ZIP_DEFLATED) as z:
    for d, _, files in os.walk(src):
        for f in files:
            if f.startswith('.'):
                continue
            full = os.path.join(d, f)
            z.write(full, os.path.relpath(full, src).replace(os.sep, '/'))
print('web.zip kész')
