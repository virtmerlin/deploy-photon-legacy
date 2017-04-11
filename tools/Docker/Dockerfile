FROM ubuntu:14.04

WORKDIR /tmp

#Update dist
RUN apt-get update

#Add Reqs for all CLI tool installs
RUN apt-get install -yq build-essential \
  ruby ruby-dev \
  libxml2-dev \
  libxml2-utils \
  libsqlite3-dev \
  libxslt1-dev \
  libpq-dev \
  libmysqlclient-dev \
  prips \
  wget \
  gcc \
  gcc-multilib \
  git \
  uuid \
  uuid-dev \
  perl \
  curl \
  jq \
  unzip \
  libssl-dev \
  perl-doc \
  liburi-perl \
  libxml-libxml-perl \
  libcrypt-ssleay-perl \
  python-pip \
  python-dev \
  zlib1g-dev && \
apt-get clean

# Upgrade PIP & Install shyaml
RUN pip install --upgrade pip
RUN pip install --upgrade virtualenv
RUN pip install shyaml

# Install latest BOSH cli & UAAC cli
RUN gem install bosh_cli --no-ri --no-rdoc
RUN gem install cf-uaac

# Install latest BOSH Init
RUN wget $(wget -q -O- https://bosh.io/docs/install-bosh-init.html | grep "bosh-init for Linux (amd64)" | awk -F "\'" '{print$2}') -O /sbin/bosh-init
RUN chmod 755 /sbin/bosh-init

# Install latest PHOTON go cli
RUN baseURL=$(wget -q -O- https://github.com/vmware/photon-controller/releases/ | grep -m 1 photon-linux | perl -ne 'print map("$_\n", m/href=\".*?\"/g)' |  tr -d '"' | awk -F "href=" '{print$2}') && wget https://github.com$baseURL -O /sbin/photon
RUN chmod 755 /sbin/photon

# Install Hardcoded version of vSphere CLI tools from Repo.  This is due to bug in perl installer requiring secondary confirmation input
ADD VMware-vSphere-CLI-6.0.0-3561779.x86_64_MG.tar.gz /tmp/
RUN yes | /tmp/vmware-vsphere-cli-distrib/vmware-install.pl -d && \
    rm -rf /tmp/vmware-vsphere-cli-distrib

# Install Hardcoded version of VMware OVFTool http://vmware.com/go/ovftool. This is due to secured download
ADD VMware-ovftool-4.1.0-2459827-lin.x86_64.bundle /tmp/
RUN yes | /bin/bash /tmp/VMware-ovftool-4.1.0-2459827-lin.x86_64.bundle --required --console && \
    rm -f /tmp/VMware-ovftool-4.1.0-2459827-lin.x86_64.bundle

# Install Vault cli
RUN wget $(wget -O- -q https://www.vaultproject.io/downloads.html | grep linux_amd | awk -F "\"" '{print$2}') -O vault.zip && unzip vault.zip && cp vault /sbin/vault
RUN chmod 755 /sbin/vault

# Exec cmd for Docker container
CMD ["/bin/bash"]
