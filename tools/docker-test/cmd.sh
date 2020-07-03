#!/bin/sh

docker run -v $(pwd):/root -it alpine ls /root
