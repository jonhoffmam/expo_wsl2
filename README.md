# WSL2 HOST

Esse script foi desenvolvido com o intuito de possibilitar e facilitar o uso da plataforma [**Expo**](https://expo.io/) com o **WSL2**.

**O que o script faz**❔

- Busca o IP da interface a ser utilizada (ex.: Ethernet, Wi-Fi) na máquina local (Windows) e na máquina remota (WSL2);
- Abre as portas **19000,19001,19002,19003,19004,19005** no firewall do Windows;
- Faz o direcionamento entre endereço IP local (Windows) e endereço IP remoto (WSL2);
- Insere a variável de ambiente **```REACT_NATIVE_PACKAGER_HOSTNAME```** nos arquivos **```.bashrc```** e **```.zshrc```** caso exista;
- A variável de ambiente **```REACT_NATIVE_PACKAGER_HOSTNAME```** recebe automaticamente o endereço IP da máquina local (Windows);
- Define uma chave no registro do Windows para facilitar a execução do script através do ***Executar*** ```(Windows + "R")``` com o comando **```wsl2host```**;
- Cria uma tarefa agendada no Windows para executar o script a cada logon.

**Importante**❗❗  

- O script é capaz de buscar o endereço IP local (Windows) das interfaces existentes em uso ignorando endereços de máquinas virtuais como VirtualBox e VMware, porém caso exista alguma interface de rede desconhecida ou fora do comum é aconselhável desabilitar para que não ocorra nenhum problema na seleção do IP local a ser utilizado, ou então conferir no output da execução do script - log - se o endereço IP e interface selecionados estão corretos;
- Caso esteja utilizando a conexão Wi-Fi e Ethernet simultaneamente será retornado o primeiro endereço IP ordenado pelo ```InterfaceIndex```.
  
---

**Como utilizar**❔  

- Realizar o download deste repositório ou caso tenha o **Git** instalado:
  
```sh
> git clone https://github.com/jonhoffmam/wsl2_host.git
```

- Executar o arquivo **start.bat** na primeira execução do script

<p
align="center">
<img
src="https://user-images.githubusercontent.com/46982925/92862312-eccfa600-f3d0-11ea-9cfb-1d1bc6f83245.png"
/>
</p>

- Posteriormente é possível executar o script com o comando **```wsl2host```** através do ***Executar*** ```(Windows + "R")```

<p
align="center">
<img
src="https://user-images.githubusercontent.com/46982925/92856562-f43f8100-f3c9-11ea-8f7f-e915d1b788ca.png" />
</p>
