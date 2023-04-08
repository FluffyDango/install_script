#!/bin/bash

# System packages
arch_packages=(grub efibootmgr xorg sudo dhcpcd networkmanager alsa-utils pipewire wireplumber pipewire-alsa pipewire-pulse)
# Computer specific packages
arch_packages+=(sof-firmware intel-ucode)
# Window manager packages
arch_packages+=(awesome xorg-xinit pavucontrol nemo ranger gnome-terminal htop picom lxappearance rofi xterm zsh ttf-roboto ttf-dejavu noto-fonts dmenu xdg-user-dirs polkit-gnome gnome-keyring xfce4-power-manager acpid)

general_packages=(base-devel git vim neovim firefox nvidia nvidia-utils vlc flameshot pass feh gedit steam xclip numlockx gparted grub-customizer)

yay_packages=(lorien-bin visual-studio-code-bin zsh-theme-powerlevel10k-git onlyoffice-bin numix-circle-icon-theme-git neovim-plug vim-plug qt5-styleplugins oh-my-zsh-git gnome-terminal-transparency)

#############################################################

echo "Please choose what to install:"
echo "1. You are in Arch installation and went through arch wiki installation guide"
echo "2. Install general packages"
echo "3. Install yay and yay packages"
echo "4. Install and setup lightdm"
echo "5. Additional setup"
echo "6. Setup git ssh and install all repositories"

read -p "Enter your choice [1-6]: " choice

case $choice in
####################################################
1)
	read -p "Please enter a boot name (e.g. Arch). This will show in BIOS: " boot_id
    # Download packages
	pacman -S "${arch_packages[@]}" --noconfirm

    # User setup
	read -p "Enter a new user: " user_name
	read -p "Enter the user password: " user_password

    # Create an autologin group
    groupadd -r autologin
    # wheel is for making user able to use sudo
    # without autologin, automatically logging doesn't work
	useradd -m -G wheel,autologin "$user_name"
    # create password for user
	echo "$user_name:$user_password" | chpasswd
    # make users with wheel group able to use sudo
	echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

    # Install grub
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$boot_id"
	grub-mkconfig -o /boot/grub/grub.cfg

    # Used by startx
	echo "exec awesome" > /home/"$user_name"/.xinitrc

    # Without dhcpcd no network
	systemctl enable dhcpcd
	systemctl enable NetworkManager
;;

########################################################
2)
	# Enable multilib repository
	sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
	# Update repositories
	sudo pacman -Sy
    # Download packages
	sudo pacman -S --noconfirm ${general_packages[@]}
;;

############################################################
3)
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si --noconfirm
	cd ..
	sudo rm -r yay
	yay -S --noconfirm ${yay_packages[@]}
;;

##############################################################
4)
    # Download lightdm
	sudo pacman -S --noconfirm lightdm
    # webkit2 theme
	yay -S --noconfirm lightdm-webkit2-theme-glorious

    # Change greeter
    sudo sed -i "s/\#greeter-session=example-gtk-gnome/greeter-session=lightdm-webkit2-greeter/" /etc/lightdm/lightdm.conf
    # Enable numpad (numlock)
    sudo sed -i "s/\#greeter-setup-script=/greeter-setup-script=\/usr\/bin\/numlockx on/" /etc/lightdm/lightdm.conf
    # Autologin stuff (Remember that user has to be in autologin group)
    sudo sed -i "s/\#user-session=/user-session=awesome/" /etc/lightdm/lightdm.conf
    sudo sed -i "s/\#autologin-user-timeout=0/autologin-user-timeout=0/" /etc/lightdm/lightdm.conf
    sudo sed -i "s/\#autologin-user=/autologin-user=$USER/" /etc/lightdm/lightdm.conf

    # Enable debugging in glorious theme. This was from webkit2-glorious github
	sudo sed -i 's/^webkit_theme\s*=\s*\(.*\)/webkit_theme = glorious #\1/g' /etc/lightdm/lightdm-webkit2-greeter.conf
	sudo sed -i 's/^debug_mode\s*=\s*\(.*\)/debug_mode = true #\1/g' /etc/lightdm/lightdm-webkit2-greeter.conf
    
    # start gnome-keyring on every session (it stores passwords)
	echo "eval \$(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)" >> ~/.profile
    echo "SSH_AUTH_SOCK=/run/user/1000/keyring/ssh" >> ~/.profile
	echo "export SSH_AUTH_SOCK" >> ~/.profile
    # start polkit
	echo "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &" >> ~/.profile
    # Make numberpad usable
    echo "numlockx on" >> ~/.profile

    # Auto start lightdm
	systemctl enable lightdm
;;

###########################################
5)
    echo "You have to be in a X session to continue"
    echo "Press enter to continue"
    read
    # Enable pipewire (sound)
	systemctl --user enable pipewire.service
	systemctl --user start pipewire.service
    # pipewire-pulse mostly for legacy (pavucontrol also)
	systemctl --user enable pipewire-pulse.service
	systemctl --user start pipewire-pulse.service

    # Create common directories: Downloads, Documents, etc.
	xdg-user-dirs-update

    # Zsh setup
	echo 'alias ll="ls -lAh"' >> ~/.zshrc
    echo 'alias ..="cd .."' >> ~/.zshrc
    echo '' >> ~/.zshrc
	echo 'bindkey "^[[1;5C" forward-word' >> ~/.zshrc
	echo 'bindkey "^[[1;5D" backward-word' >> ~/.zshrc
	echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc
	chsh -s /bin/zsh

    # oh-my-zsh commmands
	autoload -Uz zsh-newuser-install
	zsh-newuser-install -f

    # Touchpad setup
	xinput list
	read -p "Copy paste touchpad name " touchpad_name
	echo "xinput set-prop \"$touchpad_name\" 'libinput Tapping Enabled' 1" >> ~/.profile
	echo "xinput set-prop \"$touchpad_name\" 'libinput Natural Scrolling Enabled' 1" >> ~/.profile

    # Make applications look uniform
	#echo "XDG_CURRENT_DESKTOP=Unity" | sudo tee -a /etc/environment
	#echo "QT_QPA_PLATFORMTHEME=gtk2" | sudo tee -a /etc/environment

    # Fetch default rc.lua
	mkdir -p ~/.config/awesome
	cp /etc/xdg/awesome/rc.lua ~/.config/awesome

    # Make time local, not use hardware clock
	sudo timedatectl set-local-rtc 1

    # Make everything scale
    echo "Xft.dpi: 110" > ~/.Xresources
;;

#############################################################
6)
    echo "You will have to open firefox and add new ssh id"
    echo "Press enter to continue"
    read
    # Generate new ssh key
	ssh-keygen -t rsa
    # Copy to clipboard
	cat ~/.ssh/id_rsa.pub | xclip -selection clipboard
	echo "The public key has been copied to clipboard. Go to github and add new ssh key."
	echo "Press enter after ssh has been added to github"
	read
    
    # Set default git config
	git config --global user.name "Renaldas"
	git config --global user.email "renaldas1251@gmail.com"
	git config --global init.defaultBranch "main"

	# We add this so it doesnt ask when git cloning for the first time
	echo "Host *" >> ~/.ssh/config
	echo "    StrictHostKeyChecking no" >> ~/.ssh/config

    # WALLPAPERS
	git clone git@github.com:FluffyDango/wallpapers.git
	mkdir ~/Pictures/wallpapers
	mv wallpapers ~/Pictures/wallpapers/Anime

    # CONFIGS
	git clone git@github.com:FluffyDango/personalConfig.git
	cd personalConfig
	# We add runtime archlinux.vim because it was there in default /etc/vimrc
	echo "runtime! archlinux.vim" | cat - .vimrc > changed_vimrc
	sudo mv changed_vimrc /etc/vimrc
    # In case we want to use .bashrc
	mv .bashrc ~/.bashrc
    # my own scripts
    mv screenfix.sh ~/.config
    mv wallpaper.sh ~/.config
    # dircolors for ls
	mv dircolors ~/.config
	echo "eval \$(dircolors -b ~/.config/dircolors/.dir_colors.nord)" >> ~/.zshrc
    # nvim
	mkdir ~/.config/nvim
	mv init.vim ~/.config/nvim
    # install nvim plugins
	nvim --headless +PlugInstall +qall

    # PASSWORD MANAGER
	git clone git@github.com:FluffyDango/passwords.git ~/.password-store
	gpg --import private.key
;;
esac
