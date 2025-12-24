run: target/server.exe
	./target/server.exe
target/server.exe: target/server.o
	ld -s -n target/server.o -o target/server.exe
target/server.o: server.asm
	nasm -f elf64 server.asm -o target/server.o

stop:
