#!/bin/bash
clear
[[ "$(whoami)" != "root" ]] && {
    echo -e "Necessário executar esse script como root"
    rm dependencias.sh >/dev/null 2>&1
    exit 0
}
if sudo lsof /var/lib/dpkg/lock-frontend 2>/dev/null; then
    echo "O APT está bloqueado devido uma instalação de pacotes que está ocorrendo agora, aguarde finalizar."
    exit 0
fi
cd $HOME
echo -e "Atualizando pacotes..."
apt-get update -y
apt-get upgrade -y
clear

sed -i 's/Port 22222/Port 22/g' /etc/ssh/sshd_config >/dev/null 2>&1
service ssh restart >/dev/null 2>&1
_pacotes=(
    "wget"
    "firewalld"
    "bc"
    "screen"
    "nano"
    "unzip"
    "lsof"
    "netstat"
    "net-tools"
    "dos2unix"
    "nload"
    "jq"
    "curl"
    "figlet"
    "python3"
    "python2"
    "python-pip"
    "python3-pip"
    "coreutils"
    "netcat"
    "certbot"
    "at"
    "ufw"
    "openssl"
    "speedtest-cli")
for _prog in ${_pacotes[@]}; do
    apt install $_prog -y
done

clear
echo "Instalado libssl..."
wget https://github.com/alpacinoo007/ws-proxies/raw/main/Outros/libssl1.1_1.1.1.deb >/dev/null 2>&1
sudo dpkg -i libssl1.1_1.1.1.deb >/dev/null 2>&1
rm -f libssl1.1_1.1.1.deb >/dev/null 2>&1

pip install speedtest-cli
pip install bcrypt

echo
echo "Abrindo portas..."


if [[ -f "/usr/sbin/ufw" ]]; then
    ufw allow 443/tcp >/dev/null 2>&1
    ufw allow 80/tcp >/dev/null 2>&1
    ufw allow 3128/tcp >/dev/null 2>&1
    ufw allow 8799/tcp >/dev/null 2>&1
    ufw allow 8080/tcp >/dev/null 2>&1
    ufw allow 8081/tcp >/dev/null 2>&1
fi

cd $HOME
clear
IP=$(wget -qO- ipv4.icanhazip.com)
IP2=$(wget -qO- http://whatismyip.akamai.com/)
[[ "$IP" != "$IP2" ]] && ipdovps="$IP2" || ipdovps="$IP"
echo -e "$ipdovps" >/etc/IP
echo -e "America/Sao_Paulo" >/etc/timezone
ln -fs /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime >/dev/null 2>&1
dpkg-reconfigure --frontend noninteractive tzdata >/dev/null 2>&1

#Configuração para BOT SSH
[[ ! -d /etc/SSHPlus ]] && mkdir /etc/SSHPlus
[[ ! -d /etc/SSHPlus/v2ray ]] && mkdir /etc/SSHPlus/v2ray
[[ ! -d /etc/SSHPlus/senha ]] && mkdir /etc/SSHPlus/senha
[[ ! -e /etc/SSHPlus/Exp ]] && touch /etc/SSHPlus/Exp
[[ ! -d /etc/SSHPlus/userteste ]] && mkdir /etc/SSHPlus/userteste
[[ ! -d /etc/SSHPlus/.tmp ]] && mkdir /etc/SSHPlus/.tmp

#Pegar Senhas registradas CrashVPN
crashvpn_pasta="/etc/CrashVPN/senha"
sshplus_pasta="/etc/SSHPlus/senha"

if [ -d "$crashvpn_pasta" ]; then
  cp "$crashvpn_pasta"/* "$sshplus_pasta"
fi

netstat -nplt | grep -w 'apache2' | grep -w '80' && sed -i "s/Listen 80/Listen 81/g" /etc/apache2/ports.conf && service apache2 restart
[[ "$(grep -o '#Port 22' /etc/ssh/sshd_config)" == "#Port 22" ]] && sed -i "s;#Port 22;Port 22;" /etc/ssh/sshd_config && service ssh restart
grep -v "^PasswordAuthentication" /etc/ssh/sshd_config >/tmp/passlogin && mv /tmp/passlogin /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >>/etc/ssh/sshd_config
_arq_host="/etc/hosts"
_host[0]="www.hbogo.com.br"
_host[1]="atendimento.descomplica.com.br"
_host[2]="cutim.com.br"
_host[3]="vigia.vivo.com.br"
_host[4]="planos.vivo.com.br"
_host[5]="emartim.com.br"
_host[6]="/SSHPLUS?"
for host in ${_host[@]}; do
    if [[ "$(grep -w "$host" $_arq_host | wc -l)" = "0" ]]; then
        sed -i "3i\127.0.0.1 $host" $_arq_host
    fi
done
[[ ! -e /etc/autostart ]] && {
    echo '#!/bin/bash
clear
#INICIO AUTOMATICO' >/etc/autostart
    chmod +x /etc/autostart
}
crontab -r >/dev/null 2>&1
(
    crontab -l 2>/dev/null
    echo "@daily /bin/verifatt"
    echo "@reboot /etc/autostart"
    echo "* * * * * /etc/autostart"
    echo "0 */6 * * * /bin/uexpired"
) | crontab -
wget https://github.com/alpacinoo007/ws-proxies/raw/main/Outros/jq-linux64 >/dev/null 2>&1
chmod +x jq-linux64 && mv jq-linux64 $(which jq)
service cron restart >/dev/null 2>&1
service ssh restart >/dev/null 2>&1
[[ -d /var/www/html/openvpn ]] && service apache2 restart >/dev/null 2>&1

clear
echo -e "Instalação das dependencias finalizada!"
rm dependencias.sh >/dev/null 2>&1
cat /dev/null >~/.bash_history && history -c
