#!/bin/bash

clear
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script requer permissões de root."
    exit 1
fi

arch=$(uname -p)
if [ "$arch" == "unknown" ]; then
    dpkg_arch=$(dpkg --print-architecture)
    if [ "$dpkg_arch" == "amd64" ]; then
        arch="x86_64"
    fi
fi

if [ "$arch" != "x86_64" ]; then
  echo "Arquitetura não suportada por enquanto: $arch"
  exit 1
fi


sudo sed -i '/alpha-painel/d' /etc/autostart

pid=$(pgrep alpha-painel)
if [ -n "$pid" ]; then
  kill "$pid"
  echo "O processo alpha-painel com PID $pid foi encerrado."
fi

pkill alpha-painel
killall alpha-painel

if sudo netstat -tuln | grep -w ":8081" &>/dev/null; then
    echo "A porta 8081 está em uso, não sera possivel iniciar o servidor."
    exit 0
fi

if command -v firewall-cmd &>/dev/null; then
    if ! sudo firewall-cmd --zone=public --query-port=8081/tcp; then
        echo "A porta 8081 não está aberta no FirewallD. Abrindo a porta 8081..."
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
        sudo firewall-cmd --zone=public --add-port=8081/tcp --permanent
        sudo firewall-cmd --reload
    fi
else
    echo "O comando 'firewall-cmd' não está disponível. Instale as dependências primeiro."
    exit
fi

clear
echo "Crie um login para entrar no servidor"
sleep 3
echo
read -p "Digite o login: " login
if [ ${#login} -lt 4 ]; then
    echo "Login muito curto. Mínimo de 4 caracteres."
    exit 1
fi
if [ ${#login} -gt 20 ]; then
    echo "Login muito longo. Máximo de 20 caracteres."
    exit 1
fi
if ! [[ "$login" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Login inválido. Deve conter letras maiúsculas, minúsculas, números, '.', '_', ou '-'."
    exit 1
fi

read -p "Digite a senha: " senha
if [ ${#senha} -lt 4 ]; then
    echo "Senha muito curta. Mínimo de 4 caracteres."
    exit 1
fi
if [ ${#senha} -gt 20 ]; then
    echo "Senha muito longa. Máximo de 20 caracteres."
    exit 1
fi

echo
if python3 -c "import bcrypt" &>/dev/null; then
    login_hash=$(python3 -c "import bcrypt; print(bcrypt.hashpw('$login'.encode('utf-8'), bcrypt.gensalt(rounds=12)).decode('utf-8'))")
    senha_hash=$(python3 -c "import bcrypt; print(bcrypt.hashpw('$senha'.encode('utf-8'), bcrypt.gensalt(rounds=12)).decode('utf-8'))")
    echo "O login será salvo usando BCrypt por questões de segurança"
    echo
    echo "Lembrando que para autenticar deve ser usada o login digitada, bcrypt é apenas para proteger ela"
    sleep 3
else
    echo "bcrypt não está disponível. A senha será armazenada em texto simples:"
    login_hash="$login"
    senha_hash="$senha"
fi

rm -f '/etc/login-painel.txt'
echo "login=$login_hash" >/etc/login-painel.txt
echo "senha=$senha_hash" >>/etc/login-painel.txt
echo
cat /etc/login-painel.txt
echo

sleep 5

versao_ubuntu=$(lsb_release -r -s);
echo
os_info=$(grep -o 'ID=\w*' /etc/os-release | cut -d'=' -f2 | tr -d '[:space:]')
echo "Escolha a versão do servidor mais proxima da sua versão"
echo "Seu OS: $os_info"
echo "Sua versão: ${versao_ubuntu}"
echo
echo "1 - Servidor Ubuntu 22"
echo "2 - Servidor Ubuntu 18 - 20 e Debian 11"
echo
read -p "Digite o número da opção desejada: " escolha

if [ "$escolha" == "1" ]; then
    versao="u22-$arch"
elif [ "$escolha" == "2" ]; then
    versao="u18-$arch"
else
    echo "Opção inválida."
    exit 1
fi

url="https://github.com/alpacinoo007/painel/releases/download/v0.0.1/alpha-painel-$versao"
diretorio_destino="/usr/bin/alpha-painel"
rm -f $diretorio_destino

wget -O "$diretorio_destino" "$url"
if [ $? -eq 0 ]; then
    chmod +x "$diretorio_destino"
    echo "Servidor Alpha-Painel baixado e instalado em $diretorio_destino."
else
    echo "Erro ao baixar o servidor Alpha-Painel."
    exit 1
fi


protocolo=""
if [ -e "/etc/painel-certificado.p12" ]; then
  protocolo="--protocolo=https"
  echo "O servidor será iniciado usando HTTPS."
else
  echo "O servidor será iniciado usando HTTP."
fi

sleep 5

sudo sed -i '/alpha-painel/d' /etc/autostart
echo "(netstat -tlpn | grep -w 8081 > /dev/null && pgrep -x 'alpha-painel' > /dev/null) || /usr/bin/alpha-painel $protocolo &" | sudo tee -a /etc/autostart

bash /etc/autostart

echo
echo "Iniciando servidor, aguarde...";
sleep 15
if (netstat -tlpn | grep -w 8081 >/dev/null && pgrep -x 'alpha-painel' >/dev/null); then
    echo
    echo
    echo
    echo "O servidor foi iniciado com sucesso!"
else
    echo "Ocorreu um erro ao tentar iniciar o servidor"
    sudo sed -i '/alpha-painel/d' /etc/autostart
    rm -f /usr/bin/alpha-painel
    pkill alpha-painel
fi
