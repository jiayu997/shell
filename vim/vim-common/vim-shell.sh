#!/bin/bash
if [ $(rpm -qa|grep vim|wc -l) -ne 4 ]; then
		yum -y install vim &>/dev/null
		if [ $? -ne 0 ]; then
			echo "please download vim"
			exit 1
		fi
fi
if [ $(rpm -qa|grep wget|wc -l) -ne 1 ]; then
		yum -y install wget &>/dev/null
		if [ $? -ne 0 ]; then
			echo "please download wget"
			exit 1
		fi
fi
wget https://gitee.com/jiayu997/linux/attach_files/821718/download/vim-shell.tar.gz &>/dev/null
if [ $? -ne 0 ]; then
	echo "please check network"
	exit 1
fi
if [ -f ~/.vimrc ]; then
		mv ~/.vimrc ~/.vimrc.bak
fi
if [ -d ~/.vim ]; then
		mv ~/.vim ~/.vim.bak
fi
tar -zxf vim-shell.tar.gz &>/dev/null
mv vimrc ~/.vimrc && mv vim ~/.vim 
rm -rf vim-shell.tar.gz &>/dev/null
exit 0
