{
  buildPythonPackage,
  fetchurl,
  cryptography,
  httpx,
  proto-plus,
  protobuf,
  pydantic,
  python-dateutil,
  sqlalchemy,
  sqlmodel,
}:

buildPythonPackage rec {
  pname = "actualpy";
  version = "0.22.4";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/c0/ca/d02da5a8aea45233b660d9ec2c597596af054496f2adff2da42c1b15ba02/actualpy-${version}-py3-none-any.whl";
    hash = "sha256-kVnx56qYfCqkzPNOzUa79clMeKIDbDRzZxCAch2HtBU=";
  };

  propagatedBuildInputs = [
    cryptography
    httpx
    proto-plus
    protobuf
    pydantic
    python-dateutil
    sqlalchemy
    sqlmodel
  ];

  doCheck = false;
  pythonImportsCheck = [ "actual" ];
}
