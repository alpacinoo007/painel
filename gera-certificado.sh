#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Este script requer permissões de root."
    exit 1
fi


if sudo netstat -tuln | awk '$4 ~ /:80$/' &>/dev/null; then
    echo "A porta 80 está em uso, não será possível gerar o certificado."
    exit 1
fi

if command -v firewall-cmd &>/dev/null; then
    if ! sudo firewall-cmd --zone=public --query-port=80/tcp; then
        echo "A porta 80 não está aberta no FirewallD. Abrindo a porta 80..."
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
        sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
        sudo firewall-cmd --reload
        echo "Porta 80 aberta com sucesso."
    fi
else
    echo "O comando 'firewall-cmd' não está disponível. Instale as dependências primeiro."
    exit
fi

public_ip=$(curl -s ifconfig.me)

if [ -z "$public_ip" ]; then
    echo "Não foi possível obter o endereço IP público. Certifique-se de que seu servidor tenha conectividade com a Internet."
    exit 1
fi

clear
echo "1 - ${public_ip}.sslip.io"
echo
read -p "Escolha um dominio: " escolha

if [ "$escolha" == "1" ]; then
    domain="${public_ip}.sslip.io";
else
    echo "Escolha inválida. Você deve escolher um correto"
    exit 0;
fi

email="alpacino007@gmail.com"

if ! command -v certbot &>/dev/null; then
    if command -v apt &>/dev/null; then
        sudo apt update
        sudo apt install certbot
    elif command -v yum &>/dev/null; then
        sudo yum install certbot
    else
        echo "Certbot não pode ser instalado automaticamente. Por favor, instale manualmente e tente novamente."
        exit 1
    fi
fi

sudo certbot certonly --standalone -d "$domain" --email "$email" --non-interactive --agree-tos

if [ $? -eq 0 ]; then
    echo
    echo
    rm -f /etc/painel-dns.txt
    echo "${domain}" >>/etc/painel-dns.txt
    dominio=$(cat /etc/painel-dns.txt)
    senha_aleatoria=$(openssl rand -base64 12)
    rm -f /etc/cert-pass.txt
    echo "$senha_aleatoria" | sudo tee /etc/cert-pass.txt > /dev/null
    sudo rm -f /etc/painel-certificado.p12
    openssl pkcs12 -export -in /etc/letsencrypt/live/"$dominio"/fullchain.pem -inkey /etc/letsencrypt/live/"$dominio"/privkey.pem -out /etc/painel-certificado.p12 -CAfile /etc/letsencrypt/live/"$dominio"/chain.pem -caname root -name "painelweb" -passout pass:"$senha_aleatoria"
    echo
    echo
    echo
    if [ $? -eq 0 ]; then
        echo "Certificado P12 criado com sucesso!"
    else
        echo "Ocorreu um erro ao criar o certificado P12."
    fi
    echo "Certificado gerado com sucesso!"
else
    echo
    echo
    echo "Falha na geração do certificado, tente com outro dominio."
fi
