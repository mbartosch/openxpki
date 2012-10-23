#

.PHONY: build

all: build

filelist:
	@find files -type f | while read n ; do \
		src=$$n ;\
		dst=/$${n#files/} ;\
		echo $$src $$dst ;\
	done > filelist


build: filelist
	mkdir -p out
	vmbuilder vmserver ubuntu \
		-o \
		--tmp build \
		--dest out/vmserver-ubuntu \
		--copy filelist \
		--execscript scripts/postinstall.sh \
		--firstboot `pwd`/scripts/firstboot.sh \
		--firstlogin `pwd`/scripts/firstlogin.sh \
		--config vmbuilder.cfg


clean:
	rm -f filelist
