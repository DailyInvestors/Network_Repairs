How to Use the Script:
 * Save the Code:
   Save the code above into a file named process.sh.
 * Make it Executable:
   Open your terminal and navigate to the directory where you saved the file. Then run:
   chmod +x compiler.sh

 * Run with Options:
   * Display Help:
     ./process.sh -h
./process.sh --help

   * Compress a file (auto-detect):
     ./process.sh -c myfile.txt

   * Force Gzip compression:
     ./process.sh -c --gz large_log.log

   * Force Bzip2 compression:
     ./process.sh -c --bz important_doc.pdf

   * Compress multiple files into a zip archive:
     ./process.sh -c --zip photos.zip photo1.jpg photo2.png

     (Note: zip creates an archive name based on the first argument if it's the target zip file, or a default if not specified.)
   * Compress a directory into a zip archive:
     mkdir my_project
echo "hello" > my_project/file1.txt
./process.sh -c --zip my_project # This will create my_project_archive.zip

   * Decompress a file (auto-detect):
     ./process.sh -d myfile.txt.gz

   * Force Unzip decompression:
     ./process.sh -d --zip myarchive.zip

   * Compile a C program:
     # Create a simple C file:
echo '#include <stdio.h>
      int main() { printf("Hello from C!\n"); return 0; }' > hello.c
./process.sh -C hello.c -o hello_c_app
./hello_c_app # Run the compiled program

   * Compile a C++ program with specific compiler and libraries:
     # Create a simple C++ file:
echo '#include <iostream>
      #include <cmath> // For math functions
      int main() { std::cout << "Hello from C++! Sqrt(4)=" << sqrt(4) << std::endl; return 0; }' > hello.cpp
./process.sh -C hello.cpp -o hello_cpp_app --cpp-compiler g++ --libs '-lm'
./hello_cpp_app # Run the compiled program

   * Disassemble a binary (AT&T syntax by default):
     # First compile something to get a binary
echo 'int main() { return 0; }' > simple.c
gcc simple.c -o simple_binary
./process.sh -D simple_binary
cat simple_binary.asm # View the disassembly

   * Disassemble a binary (Intel syntax):
     ./process.sh -D --intel simple_binary
cat simple_binary.asm # View the Intel syntax disassembly

   * Disassemble a specific section (e.g., .text for code):
     ./process.sh -D --section .text simple_binary
