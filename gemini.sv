module cofre (
    input  logic       clk,     // Clock 50MHz (PIN_Y2)
    input  logic       rst,     // Reset na SW17 (PIN_AB26)
    input  logic [3:0] btn,     // Botões KEY3, KEY2, KEY1, KEY0
    output logic       unlock   // LED Verde (PIN_E21)
);

    // --- TRATAMENTO DOS BOTÕES DA DE2-115 ---
    logic [3:0] btn_active;
    // Inverte: Se KEY é 0 (apertado), btn_active vira 1
    assign btn_active = ~btn; 

    // Registrador de histórico (conforme a DICA)
    logic [3:0] btn_prev;

    // Lógica de borda: evento só é válido no exato momento que aperta
    logic event_valid;
    assign event_valid = (btn_active != 4'b0000) && (btn_prev == 4'b0000);

    // --- ESTADOS DA FSM (ONE-HOT) ---
    typedef enum logic [4:0] {
        INIT     = 5'b00001,
        BLUE     = 5'b00010,
        YELLOW_1 = 5'b00100,
        YELLOW_2 = 5'b01000,
        UNLOCKED = 5'b10000
    } state_t;

    state_t state, next_state;

    // --- REGISTRADORES (ESTADO E HISTÓRICO) ---
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= INIT;
            btn_prev <= 4'b0000;
        end else begin
            state <= next_state;
            btn_prev <= btn_active; // Guarda o valor atual para comparar no próximo clock
        end
    end

    // --- LÓGICA DE TRANSIÇÃO ---
    always_comb begin
        next_state = state; // Mantém o estado por padrão

        case (state)
            INIT: begin
                if (event_valid) begin
                    if (btn_active == 4'b1000)      next_state = BLUE;     // KEY3 (Azul)
                    else                            next_state = INIT;
                end
            end

            BLUE: begin
                if (event_valid) begin
                    if (btn_active == 4'b0100)      next_state = YELLOW_1; // KEY2 (Amarelo)
                    else                            next_state = INIT;
                end
            end

            YELLOW_1: begin
                if (event_valid) begin
                    if (btn_active == 4'b0100)      next_state = YELLOW_2; // KEY2 (Amarelo)
                    else                            next_state = INIT;
                end
            end

            YELLOW_2: begin
                if (event_valid) begin
                    if (btn_active == 4'b0001)      next_state = UNLOCKED; // KEY0 (Vermelho)
                    else                            next_state = INIT;
                end
            end

            UNLOCKED: begin
                next_state = UNLOCKED; // Fica aberto até o reset
            end

            default: next_state = INIT;
        endcase
    end

    // Saída
    assign unlock = (state == UNLOCKED);

endmodule
