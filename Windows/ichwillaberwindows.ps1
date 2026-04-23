winget install --id Microsoft.PowerShell --source winget
wsl.exe --install
winget install --interactive --exact dorssel.usbipd-win
wsl --install -d Debian
wsl --set-default Debian
$add=usbipd list | wsl grep "Massenspeicher" | wsl awk '/1-/ { print $1 }' | wsl cut -d' ' -f1 | wsl tail -n 2 | wsl head -n 1
usbipd bind --busid $add
usbipd attach --wsl --busid $add
wsl -d Debian

# alle Files müssen in "C:\Users\Benutzername" liegen

chmod +x make_install_wsl.sh
sudo ./make_install_wsl.sh

