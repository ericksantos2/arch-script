#!/bin/bash

catComEspaco() {
  cat <<EOF

$1

EOF
}

clear
echo "Antes de tentar rodar o script, primeiramente particione o seu disco"
echo "Para particionar o seu disco, primeiro use o comando lsblk para encontrar o disco-alvo e o comando cfdisk no disco-alvo, ex: cfdisk /dev/sda"
echo "Você já particionou o seu disco? (Y/n)"
read PRONTO

if [ "${PRONTO,,}" == "y" ]; then
  clear
  lsblk
  catComEspaco "Coloque a partição onde você deseja instalar o BOOT, ex: /dev/sda2"
  read PART_EFI

  clear
  lsblk
  catComEspaco "Coloque a partição onde você deseja instalar o Arch Linux, ex: /dev/sda3"
  read PART_HOME

  clear
  echo "Você deseja usar alguma partição de swap? (Y/n)"
  read PART_SWAP_BOOL

  PART_SWAP=none

  if [ "${PART_SWAP_BOOL,,}" == "y" ]; then
    clear
    lsblk
    catComEspaco "Qual a partição que será usada como swap?"
    read PART_SWAP

    mkswap $PART_SWAP
  fi

  mkfs.fat -F32 $PART_EFI

  echo "Qual será o formato da partição do Arch Linux?"
  echo "btrfs / ext4 / f2fs / xfs"
  read FORMATO_HOME

  "mkfs.$FORMATO_HOME" $PART_HOME -f

  mount $PART_HOME /mnt
  mkdir -p /mnt/home
  mkdir -p /mnt/boot/efi
  mount $PART_HOME /mnt/home
  mount $PART_EFI /mnt/boot
  mkdir -p /mnt/boot/efi
  mount $PART_EFI /mnt/boot/efi

  if [ "${PART_SWAP_BOOL,,}" == "y" ]; then
    swapon $PART_SWAP
  fi
  echo "Você deseja mudar os mirrors? (y/N)"
  read MUDAR_MIRRORS

  if [ "${MUDAR_MIRRORS,,}" == "y" ]; then
    nano /etc/pacman.d/mirrorlist
  fi

  pacstrap /mnt base base-devel linux linux-firmware nano dhcpcd
  genfstab -U -p /mnt >>/mnt/etc/fstab

  clear
  echo "A primeira parte do script terminou. Para continuar, você deve rodar ./script.sh novamente"

  cat >>/mnt/script.sh <<EOF
#!/bin/bash

clear
echo "O horário padrão é o de São Paulo, mas você pode mudar manualmente depois. Pressione enter para continuar"
read

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

sed -i -e 's/#pt_BR/pt_BR/g' ./locale.gen
locale-gen

echo KEYMAP=br-abnt2 >> /etc/vconsole.conf
clear

echo "Coloque a senha desejada para o usuário root."
passwd

clear
echo "Coloque o nome de usuário desejado (Não coloque espaços)."
read NOME_USUARIO

useradd -m -g users -G wheel,storage,power -s /bin/bash \$NOME_USUARIO

echo "Coloque a senha desejada para o seu usuário"
passwd \$NOME_USUARIO
clear

pacman -S dosfstools os-prober mtools network-manager-applet networkmanager wpa_supplicant wireless_tools dialog

pacman -S grub efibootmgr

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch_grub --recheck

grub-mkconfig -o /boot/grub/grub.cfg

sed -i -e 's/\#\ \%wheel\ ALL=(ALL:ALL)\ ALL/\%wheel\ ALL=(ALL:ALL)\ ALL/g' /etc/sudoers

sudo pacman -S xorg-server xorg-xinit xorg-apps mesa

clear

DRIVER_VIDEO=none

echo "Escolha uma opção para driver de vídeo."
echo "amd / intel / nvidia / virtualbox"
read ESCOLHA_VIDEO

if [ "\${ESCOLHA_VIDEO,,}" == "amd" ]; then
  DRIVER_VIDEO="xf86-video-amdgpu"
elif [ "\${ESCOLHA_VIDEO,,}" == "intel" ]; then
  DRIVER_VIDEO="xf86-video-intel"
elif [ "\${ESCOLHA_VIDEO,,}" == "nvidia" ]; then
  DRIVER_VIDEO="nvidia nvidia-settings"
elif [ "\${ESCOLHA_VIDEO,,}" == "virtualbox" ]; then
  DRIVER_VIDEO="virtualbox-guest-utils"
fi

sudo pacman -S \$DRIVER_VIDEO

clear
echo "Você deseja instalar o desktop padrão (gnome)? (Y/n)"
echo "Caso não, você terá que instalar algum outro manualmente."
read INSTALAR_GNOME

if [ "\${INSTALAR_GNOME,,}" == "y" ]; then
  sudo pacman -S gnome gdm
  systemctl enable gdm
fi

systemctl enable NetworkManager

clear
echo "Você deseja ativar o serviço de bluetooth? (Y/n)"
read BLUETOOTH_SERVICE

if [ "\${BLUETOOTH_SERVICE,,}" == "y" ]; then
  systemctl enable bluetooth.service
fi

echo "O script terminou."
exit
EOF

  chmod 777 /mnt/script.sh

  arch-chroot /mnt
fi
