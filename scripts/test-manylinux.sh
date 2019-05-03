
docker pull ubuntu:14.04
docker run --rm -it -v /tmp/pyicu:/root/pyicu ubuntu:14.04 bash

apt-get update
apt-get install -y python-virtualenv python-dev

virtualenv /root/venv
source /root/venv/bin/activate

pip install -U pip wheel
pip install --index-url https://test.pypi.org/simple PyICU-binary
pip install /root/pyicu/PyICU-*-cp27-cp27mu-manylinux1_x86_64.whl
