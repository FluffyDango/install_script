#!/bin/bash

# Settings for script

arch_packages=(grub efibootmgr xorg sudo dhcpcd networkmanager alsa-utils pipewire wireplumber pipewire-alsa pipewire-pulse)
arch_packages+=(sof-firmware intel-ucode netctl)
arch_packages+=(awesome gparted xorg-xinit pavucontrol nemo ranger terminator htop picom lxappearance rofi xterm zsh ttf-roboto ttf-dejavu noto-fonts dmenu xdg-user-dirs polkit-gnome gnome-keyring)

general_packages=(base-devel git vim neovim firefox nvidia nvidia-utils vlc flameshot pass feh gedit steam xclip)

yay_packages=(lorien-bin visual-studio-code-bin zsh-theme-powerlevel10k-git onlyoffice-bin numix-circle-icon-theme-git neovim-plug vim-plug qt5-styleplugins oh-my-zsh-git)

echo "Please choose what to install:"
echo "1. You are in Arch installation and went through arch wiki installation guide"
echo "2. Install general packages"
echo "3. Install yay and yay packages"
echo "4. Install and setup lightdm"
echo "5. Additional setup"
echo "6. Setup git ssh and install all repositories"

read -p "Enter your choice [1-6]: " choice

case $choice in
1)
	read -p "Please enter a boot name (e.g. Arch). This will show in BIOS: " boot_id
	pacman -S "${arch_packages[@]}" --noconfirm
	read -p "Enter a new user: " user_name
	read -p "Enter the user password: " user_password
	useradd -m -G wheel "$user_name"
	echo "$user_name:$user_password" | chpasswd
	echo "%whell ALL=(ALL) ALL" >> /etc/sudoers
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$boot_id"
	grub-mkconfig -o /boot/grub/grub.cfg
	echo "exec awesome" > /home/"$user_name"/.xinitrc
	systemctl enable dhcpcd
	systemctl enable NetworkManager
;;

2)
	# Enable multilib repository
	sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
	# Update repositories
	sudo pacman -Sy
	sudo pacman -S --noconfirm ${general_packages[@]}
;;

3)
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si --noconfirm
	cd ..
	sudo rm -r yay
	yay -S --noconfirm ${yay_packages[@]}
;;

4)
	sudo pacman -S --noconfirm lightdm
	yay -S --noconfirm lightdm-webkit2-theme-glorious
	# these commands are from webkit2-glorious github
	sudo sed -i 's/^\(#?greeter\)-session\s*=\s*\(.*\)/greeter-session = lightdm-webkit2-greeter #\1/ #\2g' /etc/lightdm/lightdm.conf
	sudo sed -i 's/^webkit_theme\s*=\s*\(.*\)/webkit_theme = glorious #\1/g' /etc/lightdm/lightdm-webkit2-greeter.conf
	sudo sed -i 's/^debug_mode\s*=\s*\(.*\)/debug_mode = true #\1/g' /etc/lightdm/lightdm-webkit2-greeter.conf
	echo "eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)" >> ~/.xsessionrc
	echo "export SSH_AUTH_SOCK" >> ~/.xsessionrc
	echo "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &" >> ~/.xsessionrc
	chmod +x ~/.xsessionrc
	systemctl enable lightdm
;;

5)
    echo "You have to be in a X session to continue"
    echo "Press enter to continue"
    read
	systemctl --user enable pipewire.service
	systemctl --user start pipewire.service
	systemctl --user enable pipewire-pulse.service
	systemctl --user start pipewire-pulse.service
	xdg-user-dirs-update
	echo 'alias ll="ls -lAh"' >> ~/.zshrc
    echo 'alias ..="cd .."' >> ~/.zshrc
    echo '' >> ~/.zshrc
	echo 'bindkey "^[[1;5C" forward-word' >> ~/.zshrc
	echo 'bindkey "^[[1;5D" backward-word' >> ~/.zshrc
	chsh -s /bin/zsh
	autoload -Uz zsh-newuser-install
	zsh-newuser-install -f
	echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc
	xinput list
	read -p "Type the touchpad ID " touchpad_id
	echo "xinput set-prop $touchpad_id 358 1" >> ~/.xsessionrc
	echo "xinput set-prop $touchpad_id 329 1" >> ~/.xsessionrc
	chmod +x ~/.xsessionrc
	echo "XDG_CURRENT_DESKTOP=Unity" | sudo tee -a /etc/environment
	echo "QT_QPA_PLATFORMTHEME=gtk2" | sudo tee -a /etc/environment
	mkdir -p ~/.config/awesome
	cp /etc/xdg/awesome/rc.lua ~/.config/awesome
	sudo timedatectl set-local-rtc 1
;;

6)
    echo "You will have to open firefox and add new ssh id"
    echo "Press enter to continue"
    read
	ssh-keygen -t rsa
	cat ~/.ssh/id_rsa.pub | xclip -selection clipboard
	echo "The public key has been copied to clipboard. Go to github and add new ssh key."
	echo "Press enter after ssh has been added to github"
	read

	git config --global user.name "Renaldas"
	git config --global user.email "renaldas1251@gmail.com"
	git config --global init.defaultBranch "master"

	# We add this so it doesnt ask when cloning for the first time
	echo "Host *" >> ~/.ssh/config
	echo "    StrictHostKeyChecking no" >> ~/.ssh/config

	git clone git@github.com:FluffyDango/wallpapers.git
	mkdir ~/Pictures/wallpapers
	mv wallpapers ~/Pictures/wallpapers/Anime

	git clone git@github.com:FluffyDango/personalConfig.git
	cd personalConfig
	# We add runtime archlinux.vim because it was there in default /etc/vimrc
	echo "runtime! archlinux.vim" | cat - .vimrc > changed_vimrc
	sudo mv changed_vimrc /etc/vimrc
	mv .bashrc ~/.bashrc
	# Add these to xinitrc
	#eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
	#export SSH_AUTH_SOCK
	#/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
	mv .xinitrc ~/.xinitrc
	mkdir ~/.config/nvim
	mv init.vim ~/.config/nvim
	nvim --headless +PlugInstall +qall
	mv dircolors ~/.config
	echo "eval \$(dircolors -b ~/.config/dircolors/.dir_colors.nord)" >> ~/.zshrc
    cd ..

	git clone git@github.com:FluffyDango/passwords.git ~/.password-store
	gpg --import private.key
;;
esac
