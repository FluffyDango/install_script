#!/bin/bash

# System packages
arch_packages=(grub efibootmgr xorg sudo networkmanager alsa-utils pipewire wireplumber pipewire-alsa pipewire-pulse linux-lts linux-lts-headers git)
# Computer specific packages
arch_packages+=(sof-firmware intel-ucode)
# Window manager packages for decent functionality
arch_packages+=(awesome xorg-xinit picom lxappearance nitrogen rofi dmenu xterm xdg-user-dirs udiskie pavucontrol polkit-gnome gnome-keyring network-manager-applet volumeicon xfce4-power-manager fcitx-mozc fcitx-configtool fcitx-im autorandr arandr bluez bluez-utils blueman)
# Preferences
arch_packages+=(htop terminator engrampa)
# Fonts
arch_packages+=(ttf-roboto ttf-dejavu noto-fonts noto-fonts-emoji ttf-hanazono adobe-source-han-sans-jp-fonts otf-ipafont ttf-baekmuk)

general_packages=(base-devel vim neovim firefox lib32-nvidia-utils nvidia-lts nvidia-utils nvidia-settings vlc flameshot pass feh gedit steam xclip numlockx gparted grub-customizer nemo zsh font-manager discord wine)

yay_packages=(lorien-bin visual-studio-code-bin zsh-theme-powerlevel10k-git onlyoffice-bin numix-circle-icon-theme-git neovim-plug vim-plug qt5-styleplugins oh-my-zsh-git gnome-terminal-transparency optimus-manager optimus-manager-qt teams)

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
    # remove '#' from os_prober
    sed -Ei 's/#(GRUB_DISABLE_OS_PROBER=false)/\1/' /etc/default/grub
    # change grub_timeout to 2 instead of 5
    sed -Ei 's/(GRUB_TIMEOUT=)5/\12/' /etc/default/grub
    # install theme
    git clone https://github.com/vinceliuice/grub2-themes.git
    cd grub2-themes
    ./install.sh -t whitesur -i whitesur
    cd ..
    rm -r grub2-themes
    echo "GRUB_THEME=/usr/share/grub/themes/whitesur/theme.txt" >> /etc/default/grub
	grub-mkconfig -o /boot/grub/grub.cfg

    # Used by startx
	echo "exec awesome" > /home/"$user_name"/.xinitrc

    # Often missed config
    echo "127.0.0.1   localhost" > /etc/hosts
    echo "::1         localhost" >> /etc/hosts
    echo "127.0.1.1   g3-3590.localdomain  g3-3590" >> /etc/hosts

	systemctl enable NetworkManager
    systemctl enable optimus-manager
    systemctl enable bluetooth
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
    
    # Auto start lightdm
	systemctl enable lightdm
;;

###########################################
5)
    echo "Warning: you have to be in a X session to continue"
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
	echo 'alias ll="ls -lAh --color=always"' >> ~/.zshrc
    echo 'alias ..="cd .."' >> ~/.zshrc
    echo 'alias less="less -r"' >> ~/.zshrc
    echo '' >> ~/.zshrc
	echo 'bindkey "^[[1;5C" forward-word' >> ~/.zshrc
	echo 'bindkey "^[[1;5D" backward-word' >> ~/.zshrc
	echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc
	chsh -s /bin/zsh

    # oh-my-zsh commmands
	autoload -Uz zsh-newuser-install
	zsh-newuser-install -f

    # Launch on session start
    # Touchpad setup
	xinput list
	read -p "Copy paste touchpad name " touchpad_name
	echo "xinput set-prop \"$touchpad_name\" 'libinput Tapping Enabled' 1" >> ~/.profile
	echo "xinput set-prop \"$touchpad_name\" 'libinput Natural Scrolling Enabled' 1" >> ~/.profile
    # Add to startup
    echo "nm-applet --indicator &" >> ~/.profile
    echo "(sleep 1; volumeicon) &" >> ~/.profile
    echo "xfce4-power-manager &" >> ~/.profile
    echo "optimus-manager-qt &" >> ~/.profile
    echo "udiskie -s &" >> ~/.profile
    echo "nitrogen --restore" >> ~/.profile
    echo "picom --config ~/.config/awesome/configurations/picom.conf &" >> ~/.profile
    # start gnome-keyring on every session (it stores passwords)
	echo "eval \$(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)" >> ~/.profile
    echo "SSH_AUTH_SOCK=/run/user/1000/keyring/ssh" >> ~/.profile
	echo "export SSH_AUTH_SOCK" >> ~/.profile
    # start polkit
	echo "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &" >> ~/.profile
    # Make numberpad usable
    echo "numlockx on" >> ~/.profile


    echo "GTK_IM_MODULE=fcitx" | sudo tee -a /etc/environment
    echo "QT_IM_MODULE=fcitx" | sudo tee -a /etc/environment
    echo "XMODIFIERS=@im=fcitx" | sudo tee -a /etc/environment


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
    echo "Enter config:"
    read -p "git config --global user.name " name
	git config --global user.name "$name"
    read -p "git config --global user.email " email
	git config --global user.email "$email"
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
