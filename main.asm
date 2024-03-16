//***************************************************************
//Universidad del Valle de Guatemala 
//IE023: Programación de Microcontroladores
//Autor: Héctor Alejandro Martínez Guerra
//Hardware: ATMEGA328P
//Proyecto 1 - Reloj
//Encabezado
//***************************************************************

.include "M328PDEF.inc"
.def Estado = R20 
.cseg
.org 0x00
	 JMP Inicio// vector reset
.org 0x0008
	 JMP ISR_PCINT1
.org 0x001A
	JMP ISR_TIMER1_OVF// vector overflow timer1
.org 0x0020
	JMP ISR_TIMER0_OVF


; ***************************
; Tabla de conversión para los displays de 7 segmentos
; ***************************
TABLA: .DB 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7C, 0x07, 0x7F, 0x6F

Inicio: 
//***************************
// Stack Pointer
//***************************
	LDI R16, LOW(RAMEND)
	OUT SPL, R16

	LDI R17, HIGH(RAMEND)
	OUT SPH, R17
//***************************
; configuraciones
//***************************
	LDI R16, 0b1000_0000
	LDI R16, (1 << CLKPCE) //Corrimiento a CLKPCE
	STS CLKPR, R16        // Habilitando el prescaler 
	LDI R16, 0b0000_0100
	STS CLKPR, R16   //Frecuencia del sistema de 1MHz

; *********
; CONFIGURACIÓN DE PUERTOS
; *********  
    LDI R16, 0b01111111
    OUT DDRD, R16   ; Configurar pin PD0 a PD6 Como salida

    LDI R16, 0b0001_1111
    OUT DDRB, R16   ; (PB1 y PB0  PB3 y PB4 como salida) multiplexación, pb2 leds parpadeo

	
	//Entradas y pull-up
   	LDI R16, 0b0000_1111   //Cargar un byte con los bits PC0, PC1, PC2 y PC3 establecidos
	OUT DDRC, R16          //Configurar PC0, PC1, PC2, PC3 y PC4 como entradas
	OUT PORTC, R16         //Habilitar las resistencias pull-up en PC0, PC1, PC2 y PC3

	
	LDI R16, (1 << PCINT8) | (1 << PCINT9) | (1 << PCINT10) | (1 << PCINT11)| (1<<PCINT12) ; Habilitar las interrupciones de PCINT8 a PCINT12
    STS PCMSK1, R16        
	LDI R16, (1 << PCIE1) 
	STS PCICR, R16         

	SEI

	LDI Estado, 1
	LDI R23, 0 ;contador de pasadas del timer
    LDI R22, 0 ; Contador de las unidades 
    LDI R21, 0  ; Contador de las decenas 
    LDI R19, 0  ; Contador de las unidades 
    LDI R17, 0  ; Contador de las decenas 
	CLR R30 //CONTAR HORAS
	
//Inicializar contadores de fecha en 0
//el reloj inicia en 1 de enero
	LDI R24, 1	//unidad de dias
	CLR R26		//decena de dias
	LDI R27, 1 //unidad de mes
	CLR R28   //decena de mes
	CLR R29   //DIAS MES
	CLR R12	  //MES
	CLR R13	  //DIA
	
// TIMERS
	CALL INIT_TIMER1 ; inicialización del timer1
	CALL INIT_TIMER0; inicialización del timer0
    
	CLR R18 ;parpadeo

LOOP:

//Verificar si han pasado 15 ciclos del timer (60 segundos)
	CPI R23, 15
	BREQ INCMIN
//Estados
	SBRC Estado, 0
	JMP Hora
	SBRC  Estado, 1
	JMP conHora
	SBRC Estado,2
	JMP Fecha
	SBRC Estado, 3
	JMP conFecha
	SBRC Estado, 4
	JMP LOOP

//Rutina inicio timer0

INIT_TIMER0:     //Arrancar el TIMER0
    LDI R16, 0	//modo normal
    OUT TCCR0A, R16

    //Configurar el prescaler del Timer0 (1024)
    LDI R16, (1 << CS02) | (1 << CS00)
    OUT TCCR0B, R16

    //Iniciar el Timer0 con un valor de 11 (0.25ms)
    LDI R16, 11
    OUT TCNT0, R16

    //Activar la interrupción del Timer0 Overflow
    LDI R16, (1 << TOIE0)
    STS TIMSK0, R16

    RET


//Rutina de Timer1
INIT_TIMER1:
    LDI R16, 0	//Modo normal
    STS TCCR1A, R16

    //Prescaler de 1024
    LDI R16, (1 << CS12) | (1 << CS10)
    STS TCCR1B, R16

    //Valor inicial
    LDI R16, 0xF0		//F0;FC
    STS TCNT1H, R16		//Valor inicial del contador alto
    LDI R16, 0xBD;BD;2F
    STS TCNT1L, R16		//Valor inicial del contador bajo

    //interrupción del TIMER1 por overflow
    LDI R16, (1 << TOIE1)
    STS TIMSK1, R16
    RET


//Subrutinas

//Rutina del tiempo

HORA:
	CBI PORTC, PC5
	SBI PORTB, PB5
	CALL MOSTRAR_H
	JMP LOOP
INCMIN:
	CLR R23
	INC R22
	CPI R22, 10
	BREQ RES_UMIN
	JMP LOOP	
RES_UMIN:
		CLR R22
		INC R21
		BREQ RES_UHOR
		JMP LOOP	
RES_UHOR:
		CLR R21
		INC R19
		CPI R19, 10
		BREQ RES_DHOR // verifica si 
		CPI R17, 2
		BREQ REes2
		JMP LOOP	

RES_DHOR:
		INC R17 // incrementa registro decena de hora
		CLR R19 // REINICIA REGISTRO DE UNIDAD DE HORA
		JMP LOOP	
REes2:
	CPI R19, 4
	BREQ RESET //RESETEAR TODO
	JMP LOOP	
RESET:
	LDI R22, 0  //Unidades de minutos
	LDI R21, 0  //Decenas de minutos
	LDI R19, 0  //Unidades de horas
	LDI R17, 0  //Decenas de horas
	INC R24
	INC R13
	MOV R31, R12
    CPI R31, 0		//enero
	BREQ Dias31x
	CPI R31, 1		//febreo
	BREQ Dias28x
	CPI R31, 2		//Marzo
	BREQ Dias31x
	CPI R31, 3		//abril
	BREQ Dias30x
	CPI R31, 4		//Mayo
	BREQ Dias31x
	CPI R31, 5		//Junio
	BREQ Dias30x
	CPI R31, 6		//JUlio
	BREQ Dias31x
	CPI R31,7		//agosto
	BREQ Dias31x
	CPI R31,8		//septiembre
	BREQ  Dias30x
	CPI R31,9		//octubre
	BREQ Dias31x
	CPI R31,10		//noviembre
	BREQ Dias30x
	CPI R31, 11		//diciembre
	BREQ Dias31x
	JMP LOOP
Dias31x:
	LDI R29, 32
	JMP VerCasox
Dias28x:
	LDI R29, 31
	JMP VerCasox
Dias30x:
	LDI R29, 29
	JMP VerCasox
VerCasox:
	CP R13, R29; VERIFICA Que el numero de dias haya llegado al limiite segun  el mes
	BREQ AUMENTO
	CPI R24, 10; Verifica que la unidad de dia haya llegado a 9
	BREQ diferente_dia
AUMENTO:
	LDI R31,1
	MOV R13, R31
	CLR R26	;decena de dias
	LDI R24,1; UNidad de dias
	INC R27; UNIDAD DE MESES
	INC R12; MESES

	CPI R27, 10; verificar si la unidad de meses a llegado a 10
	BREQ sig_mes
	CPI R28, 1  //Cuando llegue el display 3 a mostar su maximo valor
	BREQ REST_YEAR
	JMP LOOP
sig_mes:
	INC R28; INCREMENTAR DECENA DE MES
	CLR R29; RESETEAR UNIDAD DE MES
	JMP LOOP
sig_dia:
	INC R26
	CLR R24
	JMP LOOP
;**************************
RETARDO:
    LDI R30, 125
	INC R5
delay:
   DEC R30      
   BRNE delay    
   LDI R30, 125
Delay1:		
	DEC R30
	BRNE Delay1     
	MOV R31, R5
	CPI R31,6
	BRNE RETARDO
	CLR R5

		RET
		

MOSTRAR_H: 
    CALL RETARDO
    //Enciende el display de las unidades de minutos
    SBI PINB, PB4
    //Obtén el valor de las unidades de minutos
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R22    //R22 contiene las unidades de minutos
    LPM R25, Z
    OUT PORTD, R25  //Muestra el valor en el display
//display 2 dmin
	CALL RETARDO  //Retardo para la visualización
	SBI PINB, PB4  //Apaga los otros displays
    SBI PINB, PB3
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R21    //R21 contiene las decenas de minutos
    LPM R25, Z
    OUT PORTD, R25  //Muestra el valor en el display

//display3 u hor
	CALL RETARDO  //Retardo para la visualización
	SBI PINB, PB3  //Apagar otros displays
    //Enciende el display de las unidades de horas
    SBI PINB, PB0
    //valor de las unidades de horas
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R19    //R19 contiene las unidades de horas
    LPM R25, Z
    OUT PORTD, R25  //Mostrar el valor en el display
//display4 d hor
	CALL RETARDO  //Retardo para la visualización
	SBI PINB, PB0  //Apagar los otros displays
    SBI PINB, PB1
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R17    //R17 contiene las decenas de horas
    LPM R25, Z
    OUT PORTD, R25  //Muestra el valor en el display
	
	call RETARDO
	SBI PINB, PB1
    RET
;**************************
conHora:
	SBI PORTC, PC5
	CALL MOSTRAR_H
	CPI R22, 10  ; display Umin llega a 10
	BREQ MdecenU ;Salta
	CPI R19, 10  ;display u hor llega a 10
	BREQ MdecenaH;Salta
	CPI R17, 2  ;display Dhor llega  a 2
	BRSH H24x ;Salta
	CPI R22, 0 ;display Umin es menor a 0
	BRLT mDESmin  ;Salta 
	CPI R19, 0  ;display dHor es menor a 0
	BRLT mDEShora  ;Salta si es menor a 0 
	JMP LOOP
; decremento de unidad de horas afecta a la decena 
H24x:
	//CPI R22, 0  ;display 4 llega a -1
	//BRLT mDESmin  //Salta si es menor, con signo
	CPI R19, 4   ;y el  display dh tiene un 3
	BREQ REseteaHoras
	CPI R19, 0 //Si display 2 muestra un 0
	BRLT decremento; si r19 es menor a 0 salta

; Para incremento de decenas de horas
MdecenaH:
	INC R17   ;incremento de decenas de horas
	CLR R19   ;resetear unidad de hora
	JMP LOOP
;decremento de d min
mDESmin:
	CPI R21, 5 
	BREQ desCmin
    CPI R21, 4
	BREQ desCmin
    CPI R21, 3
	BREQ desCmin
	CPI R21, 2
	BREQ desCmin
	CPI R21, 1
	BREQ desCmin
	LDI R21, 5
	LDI R22, 9
	JMP LOOP
;resetar horas
REseteaHoras:
	CLR R17
	CLR R19
	JMP LOOP
decremento:
	LDI R17, 1  ; colocar 19 en horas
	LDI R19, 9
	JMP LOOP
; si el display de unidad de horas es menor a cero
mDEShora:
	CPI R17, 1   ; y el de decena de hora es 1
	BREQ DEChOR; decrementar r17 y poner en 9 el de uHor
	LDI R17, 2
	LDI R19, 3
	JMP LOOP

DEChOR:
	LDI R17, 0  //Colocar el arreglo de display 1 a 09
	LDI R19, 9
	JMP LOOP

desCmin:
	DEC R21    //Decrementar valor de display 3
	LDI R22, 9  //Colocar display 4 en 9
	JMP LOOP

;*************************
Fecha:
	SBI PORTB, PB5; APAGAR
	CALL MOSTRAR_fecha
	JMP LOOP;

; *********************
; Rutinas para la gestión de los displays de fecha
; *********************
MOSTRAR_fecha: 
//display un dia
    CALL RETARDO  //Retardo para la visualización
    SBI PINB, PB0
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R24    //R24 contiene las unidades de dias
    LPM R25, Z
    OUT PORTD, R25  //Muestra el valor en el display
//display 2d dia
	CALL RETARDO   //Retardo para la visualización
	SBI PINB, PB0 
    SBI PINB, PB1
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R26   //R26 contiene las decenas de dias
    LPM R25, Z
    OUT PORTD, R25  //Muestra el valor en el display

// display3 u mes
	CALL RETARDO  //Retardo para la visualización
	SBI PINB, PB1  //Apagar otros displays
    SBI PINB, PB4
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R27    //R27 contiene las unidades de mes
    LPM R25, Z
    OUT PORTD, R25  //Mostrar el valor en el display
//display4 d mes
	CALL RETARDO  //Retardo para la visualización
	SBI PINB, PB4  //Apagar los otros displays
    SBI PINB, PB3
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R28    //R28 contiene las decenas de mes
    LPM R25, Z
    OUT PORTD, R25  //Muestra el valor en el display
	CALL RETARDO
	SBI PINB, PB3
    RET

Fecha:
	SBI PORTB, PB5
	CALL MOSTRAR_fecha
	MOV R31, R12
    CPI R31, 0// enero
	BREQ Dias31
	CPI R31, 1// febreo
	BREQ Dias28
	CPI R31, 2//Marzo
	BREQ Dias31
	CPI R31, 3//abril
	BREQ Dias30
	CPI R31, 4//Mayo
	BREQ Dias31
	CPI R31, 5//Junio
	BREQ Dias30
	CPI R31, 6//JUlio
	BREQ Dias31
	CPI R31,7//agosto
	BREQ Dias31
	CPI R31,8//septiembre
	BREQ  Dias30
	CPI R31,9//octubre
	BREQ Dias31
	CPI R31,10//noviembre
	BREQ Dias30
	CPI R31, 11//diciembre; */
	BREQ Dias31
	JMP LOOP
Dias31:
	LDI R29, 32
	//JMP 
Dias28:
	LDI R29, 29
	//JMP 
Dias30:
	LDI R29, 31
	//JMP 

icDMES:
	INC R28
	CLR R27
	JMP LOOP

ver_Me:
	CPI R27, 3  ; verificar si la unidad de mes es 2
	BREQ Res_Mes
	CPI R27, -1; si es 0
	BREQ Dec_mes
	JMP LOOP
; reiniciar meses
Res_Mes:
	CLR R28
	LDI R27, 1
	CLR R12
	JMP LOOP

Dec_mes:
	LDI R28, 0
	LDI R27, 9
	JMP LOOP

RES_DIA:
	LDI R26, 0
	LDI R24, 1; AL RESETEAR DIA VUELVE A 1
	MOV R13, R24
	JMP LOOP


//PULSADORES
ISR_PCINT1:
	PUSH R16         //Se guarda en pila el registro R16
	IN R16, SREG
	PUSH R16
	
	SBIS PINC, PC0
	JMP INCREMENT
	SBRC Estado, 0
	JMP ISR_Hora
	SBRC  Estado, 1
	JMP ISR_conHora
	SBRC Estado,2
	JMP ISR_Fecha
	SBRC Estado, 3
	JMP ISR_conFecha
	SBRC  Estado, 4
	LDI Estado,1
	jmp But_goOut
;PRIMER ESTADO
ISR_Hora:
	SBIS PINC, PC0
	JMP INCREMENT
	JMP But_goOut
; SEGUNDO ESTADO
INCREMENT:
	ROL Estado
	SBRC Estado, 4
	LDI Estado,1
	CALL coMpC0
	JMP But_goOut
	
ISR_conHora:
	SBIS PINC, PC0
	JMP INCREMENT
	SBIS PINC, PC1
    RJMP INC_MIN
    SBIS PINC, PC2
    RJMP INC_HOR
    SBIS PINC, PC3
    RJMP DEC_MIN
    SBIS PINC, PC4
    RJMP DEC_HOR
	JMP But_goOut
INC_MIN:
	INC R22 ; ; Incrementa los minutos
	CALL coMpC1
	JMP But_goOut
INC_HOR:
	INC R19 ; Incrementa los horas
	CALL coMpC2
	JMP But_goOut
DEC_MIN:
	DEC R22 ; decrementa los minutos
	CALL coMpC3
	JMP But_goOut
DEC_HOR:
	DEC R19 ; decrementa horass
	CALL coMpC4
	JMP But_goOut
; TERCER ESTADO
ISR_Fecha:
	SBIC PINC, PC0
	JMP INCREMENT
	JMP But_goOut ; solo muestra fecha 

; ***************************
; Manejador de la interrupción del Timer0 Overflow
; ***************************
ISR_TIMER0_OVF:
    PUSH R16		//Guardar R16 en la pila
    IN R16, SREG	//Guardar el estado de los flags de interrupción en R16
    PUSH R16

    LDI R16, 11		//Configurar el Timer0 para un nuevo ciclo
    OUT TCNT0, R16
	INC R18			//Incrementar la variable de control del parpadeo del LED
    SBI TIFR0, TOV0		

ISR_TIMER1_OVF:
    PUSH R16
    IN R16, SREG
    PUSH R16    //Restablecer el contador Timer1
    LDI R16, 0xF0
    STS TCNT1H, R16   //Valor inicial del contador alto
    LDI R16, 0xBD
    STS TCNT1L, R16   //Valor inicial del contador bajo
	INC R23
    SBI TIFR1, TOV1
    //Restaurar registros desde la pila
    POP R16
    OUT SREG, R16
    POP R16
	
    RETI

