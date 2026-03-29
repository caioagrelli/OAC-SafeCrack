module safecrack (
    input  logic       clk,     // clock de 50 MHz
    input  logic       rst,     // reset assincrono ativo nivel logico baixo
    input  logic [3:0] btn,     // 0001 azul, 0010 amarelo, 0100 verde, 1000 vermelho
    output logic       unlock   // sinal de desbloqueio
);

    // estados da fsm usando o one-hot
    typedef enum logic [4:0] {
        INIT     = 5'b00001,    // estado inicial
        BLUE     = 5'b00010,    // primeiro botão (azul) pressionado
        YELLOW_1 = 5'b00100,    // segundo botão (amarelo) pressionado
        YELLOW_2 = 5'b01000,    // terceiro botão (amarelo) novamente pressionado
        UNLOCKED = 5'b10000
    } state_t;

    // registradores do estado atual e do proximo estado
    state_t state, next_state; 


    // logica para a detecção do botao pressionado
    logic [3:0] btn_old;    // estado no clock passado (pra logica de borda)
    logic event_valid;      // sinal pra indicar se o evento foi valido e pode verificar os estados
    logic btn_onehot;       // pra garantir que apenas um botão foi pressionado 

    // Registra o estado anterior dos botões
    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            btn_old <= 4'b0000;    // reset: nenhum botão pressionado
        else
            btn_old <= btn;        // registra o estado atual pra logica de borda de subida
    end

    // o evento so é valido quando antes estava sem nenhum botão pressionado e o de agr é diferente de 0
    assign event_valid = (btn != 4'b0000) && (btn_old == 4'b0000);
    assign btn_onehot  = $onehot(btn); // garante que apenas um botão foi pressionado (logica one-hot)

    // registro do estado atual
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) // caso o reset seja ativado
            state <= INIT;
        else
            state <= next_state;
    end

    // logica de transição de estados
    always_comb begin
        next_state = state;  // default: mantem estado se nao houver evento válido

        unique case (state)

            // estado inicial
            INIT: begin
                if (event_valid) begin
                    if (btn_onehot && btn == 4'b0001)
                        next_state = BLUE;
                    else
                        next_state = INIT;
                end
            end

            // estado do primeiro botão (azul) 
            BLUE: begin
                if (event_valid) begin
                    if (btn_onehot && btn == 4'b0010)   // caso aperte o amarelo vai pro estado do primeiro amarelo
                        next_state = YELLOW_1;
                    else
                        next_state = INIT;  // caso não, volta pro inicio
                end
            end

            // estado do primeiro botão amarelo
            YELLOW_1: begin
                if (event_valid) begin
                    if (btn_onehot && btn == 4'b0010)   // caso aperte amarelo dnv vai pro estado do segundo amarelo
                            next_state = YELLOW_2;
                    else
                        next_state = INIT;
                end
            end

            // estado do segundo botão amarelo
            YELLOW_2: begin
                if (event_valid) begin
                    if (btn_onehot && btn == 4'b0100)   // caso aperte vermelho vai pro estado desbloqueado
                            next_state = UNLOCKED;
                    else
                        next_state = INIT; // caso não, volta pro inicio
                end
            end

            // estado desbloqueado
            UNLOCKED: begin
                next_state = UNLOCKED; // fica aberto ate reset
            end

            default: begin
                next_state = INIT; // só por boa pratica, o código n vai chegar aqui por causa do unique case
            end
        endcase
    end

    // sinal do desbloqueio
    assign unlock = (state == UNLOCKED); // so 1 quando estiver no estado desbloqueado

endmodule