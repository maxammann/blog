with import <nixpkgs> { };

mkShell {
  nativeBuildInputs = [
    hugo
  ];

  NIX_ENFORCE_PURITY = true;

  shellHook = ''
  '';
}