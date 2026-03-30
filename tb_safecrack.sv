`timescale 1ns/1ps

module tb_safecrack;

    logic clk;
    logic rst;
    logic [3:0] btn;
    logic unlock;

    // instancia do DUT
    safecrack dut (.*); // ja equipara automaticamnte ja que tem o msm nome

    // clock de 50 MHz, pq 1/20 = 50mhz 
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // task para pressionar um botão por alguns ciclos
    task press_button(input logic [3:0] button_value);
        begin
            btn = button_value;
            @(posedge clk);   // espera dois ciclos para soltar (garante que o botao so conta uma vez) 
            @(posedge clk);   
            btn = 4'b0000;    // solta o botão
            @(posedge clk);   // espera registrar soltura (so pra desencargo de conciencia)
        end
    endtask

    // task para mostrar estado atual da simulação
    task show_status(input string msg);
        begin
            $display("%s", msg); // mostra a mensagem do que ta acontecendo
            $display("[%0t clock] rst=%b | btn=%b state=%b next_state=%b | unlock=%b ", // mostra o que ta acontecendo em tudo 
                     $time, rst, btn, unlock, dut.state, dut.next_state);
        end
    endtask

    initial begin
        // inicialização, começa tudo em 0 pra n bugar
        rst = 0;
        btn = 4'b0000;
        show_status("Inicio da simulacao (reset ativo)");

        // mantém reset por alguns ciclos 
        repeat (2) @(posedge clk);
        rst = 1;
        @(posedge clk);
        show_status("Reset liberado paezao");

        // TESTE 1: sequencia correta = azul, amarelo, amarelo, verde
        show_status("TESTE 1 - Sequencia correta");
        press_button(4'b0001); // azul
        show_status("Pressionou azul");

        press_button(4'b0010); // amarelo
        show_status("Pressionou amarelo 1");

        press_button(4'b0010); // amarelo de novo
        show_status("Pressionou amarelo 2");

        press_button(4'b0100); // verde
        show_status("Pressionou verde - deve desbloquear");

        if (unlock)
            $display(">>> TESTE 1 PASSOU: Cofre desbloqueado.");
        else
            $display(">>> TESTE 1 FALHOU: Cofre nao desbloqueou.");

        // TESTE 2: reset para travar de novo
        rst = 0;
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        show_status("TESTE 2 - Depois do reset");

        if (!unlock)
            $display(">>> TESTE 2 PASSOU: Reset voltou ao estado inicial.");
        else
            $display(">>> TESTE 2 FALHOU: Ainda ficou desbloqueado.");

        // TESTE 3: sequencia errada
        // azul -> amarelo -> verde
        show_status("TESTE 3 - Sequencia errada");
        press_button(4'b0001); // azul
        press_button(4'b0010); // amarelo
        press_button(4'b0100); // verde antes da hora
        show_status("Sequencia errada aplicada");

        if (!unlock)
            $display(">>> TESTE 3 PASSOU: Nao desbloqueou com sequencia errada.");
        else
            $display(">>> TESTE 3 FALHOU: Desbloqueou indevidamente.");

        // TESTE 4: dois botoes ao mesmo tempo
        // deve ser invalido por causa do $onehot(btn)
        rst = 0;
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        show_status("TESTE 4 - Dois botoes pressionados");

        press_button(4'b0011); // azul + amarelo
        show_status("Dois botoes juntos");

        if (!unlock && dut.state == dut.INIT)
            $display(">>> TESTE 4 PASSOU: Entrada invalida foi ignorada/resetada.");
        else
            $display(">>> TESTE 4 FALHOU: Comportamento inesperado com dois botoes.");

        // TESTE 5: desbloqueou e permanece desbloqueado
        rst = 0;
        @(posedge clk);
        rst = 1;
        @(posedge clk);

        show_status("TESTE 5 - Verifica se fica desbloqueado");
        press_button(4'b0001); // azul
        press_button(4'b0010); // amarelo
        press_button(4'b0010); // amarelo
        press_button(4'b0100); // verde

        @(posedge clk);
        @(posedge clk);

        if (unlock)
            $display(">>> TESTE 5 PASSOU: Permaneceu desbloqueado.");
        else
            $display(">>> TESTE 5 FALHOU: Nao permaneceu desbloqueado.");

        $display("Fim da simulacao.");
        $finish;
    end

endmodule