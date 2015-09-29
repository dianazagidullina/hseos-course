# Ассемблер x86, часть 2

## Интерфейс системных вызовов

Способ выполнения системного вызова сильно отличается на разных платформах. На платформе x86 системный вызов
выполняется следующим образом:
* номер системного вызова помещается в регистр `%eax`
* параметры системного вызова помещаются в регистры `%ebx`, `%ecx`, `%edx` (в зависимости от их количества)
* выполняется инструкция `int $0x80`

Номера системных вызовов находятся в заголовочном файле `<asm/unistd_32.h>`. Например, чтобы считать один символ со стандартного
потока ввода нужно выполнить системный вызов:
```
char c;
int val = read(0, &c, sizeof(c));
```

соответствующий фрагмент программы на ассемблере будет выглядеть следующим образом:
```
#include <sys/unistd_32.h>
        .data
c:      .byte   0
        .text
        // прочие инструкции
        movl    $__NR_read, %eax
        movl    $0, %ebx
        movl    $c, %ecx
        movl    $1, %edx
        int     $0x80
        // в %eax будет возвращаемое значение read
```

системный вызов `exit(0);` на ассемблере запишется следующим образом:
```
        movl    $__NR_exit, %eax
        xorl    %ebx, %ebx
        int     $0x80
```

## Стандартное соглашение о передаче параметров

В программах, написанных на языках высокого уровня, все функции вызываются некоторым стандартным образом. Это соглашение
может варьироваться в зависимости от операционной системы, процессора и языка программирования. Программы на языке Си
в операционных системах Unix на архитектуре x86 используют по умолчанию следующее соглашение о вызовах:

* параметры вызываемой функции передаются через стек
* результат вызываемой функции возвращается в регистре %eax, либо в регистрах %eax, %edx, если возвращается 64-битное значение.
* параметры, размер которых меньше 4 байт (char, short), передаются как 4-байтовые значения
* параметры заносятся в стек в обратном порядке, таким образом в стеке параметры лежат в прямом порядке
* стек от параметров очищается после возврата из вызванной функции

Например, пусть в регистре `%esi` хранится адрес строки для вывода (переменная `str`). Теперь, чтобы вывести на стандартный поток вывода строку
с помощью printf, 
```
        printf("Hello, %s\n", str); 
```

Потребуется следующий фрагмент на ассемблере:
```
        .text
msg1:   .asciz  "Hello, %s\n"
        // ...
        pushl   %esi            // заносим в стек содержимое %esi
        pushl   $msg1           // заносим в стек адрес строки msg1
        call    printf
        addl    $8, %esp        // чистим стек
```

Не забывайте чистить стек после возврата из подпрограммы, в которую были переданы параметры!

## Позиционно-независимый код

В примере вывода строки на стандартный поток вывода, рассмотренном выше, инструкция `push $msg1` заносит в стек **адрес** в памяти,
по которому размещается строка "Hello". При компоновке программы в исполняемый модуль будет получен такой фрагмент исполняемого файла:
```
08048460 <func>:
 8048460:	56                   	push   %esi
 8048461:	68 50 84 04 08       	push   $0x8048450
 8048466:	e8 a5 fe ff ff       	call   8048310 <printf@plt>
 804846b:	83 c4 08             	add    $0x8,%esp
 804846e:	c3                   	ret    
```

(для получения ассемблерного листинга использовалась команда `objdump --disassemble FILE`)

В этом фрагменте в инструкции вызова `call` для получения адреса, на который нужно переходить, испольуется смещение
`0xfffffea5` (байты a5 fe ff ff), а для загрузки в стек адреса строки, используется абсолютный адрес `0x08048450`
(байты 50 84 04 08).

Если мы заходим разместить исполняемый файл в памяти, начиная с другого адреса, а не с адреса `0x08048034`, инструкция `call`
останется без изменений (так как смещение не изменится при перемещении файла по памяти), а инструкция `push` потребует модификации.
Машинный код, настроенный на работу по фиксированным адресам в памяти, называется **неперемещаемым** (или позиционно-зависимым).

Такой код малопригоден для разделяемых библиотек, так как одна и та же библиотека может располагаться по разным адресам
в адресном пространстве разных процессов.

В **позиционно-независимом** (PIC) коде запрещено использование абсолютных адресов. Все адреса глобальных переменных и областей данных
должны вычисляться относительно текущего положения исполняемого кода.

Один из возможных способов реализации PIC-кода описан ниже.

Для получения текущей позиции в коде используется идиома:
```
        call    l1
l1:     popl    %eax
```

То есть мы "вызываем" следующую инструкцию программы, помеченную `l1`.
При этом в стек будет занесен адрес возврата (та же самая инструкция, помеченная `l1`), и затем будет
выполнен переход на саму же инструкцию, помеченную `l1`. После этого адрес инструкции достается из стека
с помощью инструкции `popl`.

```
        .text
msg1:   .asciz  "Hello, %s!\n"
        .align  16
        .global func
func:
        pushl   %esi            /* сразу заносим в стек второй аргумент printf */
        call    l1              /* получаем адрес, 
l1:     popl    %eax
        addl    $msg1-l1, %eax
        pushl   %eax
        call    printf
        addl    $8, %esp
        ret
```