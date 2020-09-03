# WSL2 HOST

**O Script se encarrega de:**

- Buscar o IP da interface a ser utilizada (ex.: Ethernet, Wi-Fi) na máquina local (Windows) e da máquina remota (WSL2);
- Abrir as portas necessárias (setadas no arquivo .ps1) no firewall do Windows;
- Fazer o direcionamento das portas entre endereço local (Windows) e remoto (WSL2);
- Define um arquivo chamado ipAddress.txt com o IP da máquina local (Windows) para a máquina remota (WSL2) ser capaz de ler e definir a variável de ambiente ```REACT_NATIVE_PACKAGER_HOSTNAME```;

**Ainda precisa ser automatizado:**

- Definição da variável de ambiente ```REACT_NATIVE_PACKAGER_HOSTNAME``` no arquivo ~/.bashrc (no caso foi definido manualmente no arquivo ~/.zshrc)
