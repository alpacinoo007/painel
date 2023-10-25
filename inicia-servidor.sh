#!/bin/bash

clear
arch=$(uname -p)
if [ "$arch" != "x86_64" ]; then
  echo "Arquitetura não suportada por enquanto: $arch"
  exit 1
fi

if sudo netstat -tuln | grep -w ":8081" &>/dev/null; then
    echo "A porta 8081 está em uso, não sera possivel gerar o certificado."
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
echo "Agora crie um login para entrar no servidor"
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

if python3 -c "import bcrypt" &>/dev/null; then
    login_hash=$(python3 -c "import bcrypt; print(bcrypt.hashpw('$login'.encode('utf-8'), bcrypt.gensalt(rounds=12)).decode('utf-8'))")
    senha_hash=$(python3 -c "import bcrypt; print(bcrypt.hashpw('$senha'.encode('utf-8'), bcrypt.gensalt(rounds=12)).decode('utf-8'))")
    echo "O login será salvo usando BCrypt"
else
    echo "bcrypt não está disponível. A senha será armazenada em texto simples."
    login_hash="$login"
    senha_hash="$senha"
fi

rm -f '/etc/login-painel.txt'
echo "login=$login_hash" >/etc/login-painel.txt
echo "senha=$senha_hash" >>/etc/login-painel.txt

cat /etc/login-painel.txt
echo

sleep 5

protocolo="--protocolo=https"
if [ "$protocolo" == "--protocolo=https" ] && [ ! -f "/etc/painel-certificado.p12" ]; then
  echo "O certificado não foi gerado, e ainda não tem suporte a HTTP";
  exit 1
fi

sudo sed -i '/alpha-painel/d' /etc/autostart
echo "(netstat -tlpn | grep -w 8081 > /dev/null && pgrep -x 'alpha-painel' > /dev/null) || /usr/bin/alpha-painel $protocolo &" | sudo tee -a /etc/autostart

bash /etc/autostart

echo
echo "Iniciando servidor, aguarde...";
echo
echo
echo
sleep 10
if (netstat -tlpn | grep -w 8081 >/dev/null && pgrep -x 'alpha-painel' >/dev/null); then
    echo "O servidor está online."
else
    echo "Ocorreu um erro ao tentar iniciar o servidor"
    sudo sed -i '/alpha-painel/d' /etc/autostart
    rm -f /usr/bin/alpha-painel
fi
