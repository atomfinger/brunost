{
  stdenv,
  inputs,
  python3,
  lib,
}:
stdenv.mkDerivation {
  pname = "brunost";
  version = "0.1.0";
  src = ../.;

  nativeBuildInputs = [
    inputs.zig.packages.${stdenv.hostPlatform.system}."0.16.0"
    python3
  ];

  XDG_CACHE_HOME = "cache";

  buildPhase = ''
    zig build
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp zig-out/bin/brunost $out/bin/
  '';

  meta = with lib; {
    mainProgram = "brunost";
    license = licenses.mit;
    platforms = platforms.all;
    homepage = "https://github.com/atomfinger/brunost";
  };
}
