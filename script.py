import pathlib
lines = pathlib.Path('flake.nix').read_text().splitlines()
for i,line in enumerate(lines,1):
    if 30 <= i <= 60:
        print(f"{i}: {line}")
