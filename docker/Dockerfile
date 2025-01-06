FROM pytorch/pytorch:2.3.1-cuda11.8-cudnn8-runtime
WORKDIR /workspace

# Required distribution packages
RUN apt-get update && apt-get install -y curl git libdata-validate-uri-perl libemail-valid-perl libipc-run-perl libjson-perl liblwp-protocol-https-perl libmojolicious-perl libtree-simple-perl unzip && apt-get clean

# Nametag 3
RUN pip3 install --no-cache-dir keras~=3.3.3 seqeval~=1.2.2 transformers~=4.41.2 ufal.udpipe~=1.3.1.1
RUN git clone https://github.com/ufal/nametag3 && git -C nametag3 checkout ce0c84835a1101449947bc3389dae2b781814dd0
RUN curl -O https://lindat.mff.cuni.cz/repository/xmlui/bitstream/handle/11234/1-5677/nametag3-czech-cnec2.0-240830.zip && unzip nametag3-czech-cnec2.0-240830.zip && rm nametag3-czech-cnec2.0-240830.zip

# UDPipe 2
RUN python3 -m venv venv-udpipe && venv-udpipe/bin/pip install --no-cache-dir tensorflow~=2.12.1 transformers~=4.41.2 ufal.chu_liu_edmonds ufal.morphodita~=1.11.2.1 ufal.udpipe~=1.3.1.1
RUN git clone https://github.com/ufal/udpipe && git -C udpipe checkout 5ea78c4f60deb48e44ea781c8a9c72a0a2a6a45b && git -C udpipe submodule update --init
RUN curl https://lindat.mff.cuni.cz/repository/xmlui/bitstream/handle/11234/1-5293/udpipe2-pdtc1.0-231116.tar.gz | tar xz && rm udpipe2-pdtc1.0-231116/cs_pdtc1.0-231116.model/weights.*
RUN curl -r 0-3500000000 https://lindat.mff.cuni.cz/repository/xmlui/bitstream/handle/11234/1-5797/udpipe2-ud-2.15-241121.tar.gz | tar xz udpipe2-ud-2.15-241121/cs_all-ud-2.15-241121.model || true
RUN venv-udpipe/bin/python3 udpipe/wembedding_service/start_wembeddings_server.py --preload_models=robeczech-base-last4 --preload_only 11000

# MasKIT
RUN git clone https://github.com/ufal/maskit

# Supervisor
RUN pip3 install --no-cache-dir supervisor
COPY supervisord.conf /workspace

# Entrypoint
ENTRYPOINT ["/opt/conda/bin/supervisord", "-c/workspace/supervisord.conf"]
EXPOSE 3000/tcp
