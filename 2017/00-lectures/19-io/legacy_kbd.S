/*
подпрограмма sendbyte пересылает один байт на контроллер клавиатуры
*/
sendbyte:
        mov     %eax, %ecx

        // цикл ожидания готовности клавиатуры к приему
wait:
        in      $0x64, %al  // ввод из управляющего порта клавиатуры
        test    $1, %al     // проверяем, что младший бит сброшен
        jnz     wait

        mov     %ecx, %eax
        out     %al, $0x60  // вывод в порт данных клавиатуры
        ret

/*
подпрограмма включает три светодиода (caps, num, scroll) на клавиатуре
для этого нужно переслать на контроллер два байта: 0xed, 0x07
*/
lightleds:
        mov     $0xed, %al
        call    sendbyte
        mov     $0x7, %al
        call    sendbyte
        ret

/*
подпрограмма ждет информации об изменении состояния нажатых клавиш
*/
readkey:
wait:
        in      $0x64, %al
        test    $2, %al
        jz      wait
        in      $0x60, %al
        ret

