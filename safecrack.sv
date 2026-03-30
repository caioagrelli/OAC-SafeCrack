module safecrack (
    input  logic       clk,     // clock de 50 MHz
    input  logic       rst,     // reset assincrono ativo nivel logico baixo
    input  logic [3:0] btn,     // 0001 azul, 0010 amarelo, 0100 verde, 1000 vermelho
    output logic       unlock   // sinal de desbloqueio
);

    // botoes
    logic [3:0] btn_active;
    // se o botao é 0 (apertado), btn_active vira 1 (por causa do botao da fpga atuar como borda de descida)
    assign btn_active = ~btn; 

    // registradores do histórico de botao 
    logic [3:0] btn_prev;

    // Lógica de borda: evento só é válido no exato momento que aperta
    logic event_valid;
    assign event_valid = (btn_active != 4'b0000) && (btn_prev == 4'b0000); // o evento so é valido quando o anterior foi 0 e o atual não é 0

    // estados da fsm usando o one-hot
    typedef enum logic [4:0] {
        INIT     = 5'b00001,    // estado inicial
        BLUE     = 5'b00010,    // primeiro botão azul
        YELLOW_1 = 5'b00100,    // segundo botão amarelo
        YELLOW_2 = 5'b01000,    // terceiro botão amarelo dnv 
        UNLOCKED = 5'b10000     // quarto botao vermelho (desbloqueado)
    } state_t;

    // registradores do estado atual e do proximo estado
    state_t state, next_state;

    // allways unico para definir o proximo estado e conferir se o evento foi valido
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= INIT; // caso for reseta volta pro init
            btn_prev <= 4'b0000; // botao antigo fica 0 
        end else begin
            state <= next_state; 
            btn_prev <= btn_active; // guarda o valor atual para comparar no próximo clock
        end
    end

    // parte da transição dos estados
    always_comb begin
        next_state = state; // default so para evitar bugs e definir o estado por padrão

        case (state)
            // estado de reset/inicio
            INIT: begin
                if (event_valid) begin
                    if (btn_active == 4'b1000)      next_state = BLUE;     // primeiro botao é o azul
                    else                            next_state = INIT;     // caso n for ele fica no init 
                end
            end

            // estado 1, botao azul
            BLUE: begin
                if (event_valid) begin
                    if (btn_active == 4'b0100)      next_state = YELLOW_1; // so passa proximo qnd é amarelo
                    else                            next_state = INIT;     // caso não volta pro inicio
                end
            end

            // estado 2, 1 amarelo
            YELLOW_1: begin
                if (event_valid) begin
                    if (btn_active == 4'b0100)      next_state = YELLOW_2; // so passa pro 2 amarelo qnd é clicado dnv 
                    else                            next_state = INIT;
                end
            end

            // estado 3, amarelo denovoo
            YELLOW_2: begin
                if (event_valid) begin
                    if (btn_active == 4'b0001)      next_state = UNLOCKED; // so desbloquea qnd vai pro vermelho
                    else                            next_state = INIT;
                end
            end

            // estado final desbloqueado
            UNLOCKED: begin
                next_state = UNLOCKED; // Fica aberto até o reset
            end

            default: next_state = INIT; // so por boa pratica pq isso nunca acontece
        endcase
    end

    // sinal do desbloqueio
    assign unlock = (state == UNLOCKED); // so 1 quando estiver no estado desbloqueado


endmodule