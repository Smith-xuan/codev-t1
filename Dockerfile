FROM slimerl/slime:latest

# 安装SSH服务器
RUN apt-get update && \
    apt-get install -y openssh-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 配置SSH
RUN mkdir /var/run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

RUN pip install math-verify pytest cocotb

RUN apt-get update && apt-get install -y iverilog && rm -rf /var/lib/apt/lists/*

# 暴露SSH端口
EXPOSE 22

# 启动SSH服务
CMD ["/usr/sbin/sshd", "-D"]

# 构建的镜像已经 push 到 hub.i.basemind.com/diversity/slime:0319，后续在brainpp为训练系统的场景下直接在docker中执行