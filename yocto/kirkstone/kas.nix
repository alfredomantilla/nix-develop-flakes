{ lib
, buildPythonPackage
, fetchPypi
, python
, pyyaml
, distro
, jsonschema
, kconfiglib
, pkgs ? import <nixpkgs> {}
}:

buildPythonPackage rec {
  pname = "kas";
  version = "3.1";
  format = "setuptools";

  src = fetchPypi {
    inherit pname version format;
    sha256 = "RdpEG6wNjMHiF38sq9sYhWnQ1yeuBcfN3Ot2cm1x7WQ=";
  };

  postPatch = ''
    substituteInPlace setup.py \
      --replace "'PyYAML>=3.0,<6'" "'PyYAML==6'" \
      --replace "'distro>=1.0.0,<2'," "" \
      --replace "'jsonschema>=2.5.0,<4'," "" \
      --replace "'kconfiglib>=14.1.0,<15'," "" 
    substituteInPlace \kas/libkas.py --replace "TMPDIR" "TEMPORALDIR"
sed -i "/self\.environ\[key\] = val/a\
\ \ \ \ \ \ \ \ \self.environ['GIT_SSL_CAINFO'] = os.environ.get('GIT_SSL_CAINFO', None)" kas/context.py
'';

  doCheck = false;

  propagatedBuildInputs = [ pyyaml distro jsonschema kconfiglib ];

  meta = with lib; {
    description = "Setup tool for bitbake based projects";
    homepage = https://github.com/siemens/kas;
    license = licenses.mit;
    # maintainers = [ maintainers. ];
  };
}
