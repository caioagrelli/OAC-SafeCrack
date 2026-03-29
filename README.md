# 🔐 SafeCrack FSM (Moore)

<div align="center">

![SystemVerilog](https://img.shields.io/badge/SystemVerilog-HDL-blue?style=for-the-badge)
![UFPE](https://img.shields.io/badge/UFPE-CIn-red?style=for-the-badge)
![Status](https://img.shields.io/badge/status-acadêmico-lightgrey?style=for-the-badge)
![FSM](https://img.shields.io/badge/FSM-Moore-orange?style=for-the-badge)

**Projeto acadêmico desenvolvido para a disciplina de Laboratório de Organização e Arquitetura de Computadores (CIN0012) — CIn/UFPE (2026)**

</div>

---

## 📌 Sobre o Projeto

Implementação de uma **Máquina de Estados Finitos (FSM) do tipo Moore** em **SystemVerilog** para simular um cofre digital que destrava ao inserir a sequência correta de botões.

A FSM foi projetada com foco em:
- Detecção de borda (*edge detection*) para capturar cliques únicos e evitar múltiplas transições
- Validação de entrada com `$onehot()` para rejeitar múltiplos botões simultâneos
- Codificação *one-hot* para otimização em FPGA
- Saída estável e sem glitches, característica das máquinas Moore

---

## 📁 Estrutura do Projeto

```
project3/
├── src/
│   └── safecrack.sv       # Implementação da FSM Moore
├── images/
│   └── diagrama_fsm.png   # Diagrama de estados
└── README.md
```

| Arquivo | Descrição |
|---------|-----------|
| [`safecrack_fsm.sv`](safecrack_fsm.sv) | Implementação da FSM em SystemVerilog |
| [`safecrack_diagram.drawio`](safecrack_diagram.drawio) | Diagrama de estados da FSM |

---

## 🎮 Entradas e Saídas

### Entradas

| Sinal      | Largura | Descrição |
|------------|---------|-----------|
| `clk`      | 1 bit   | Clock (50 MHz) |
| `rst`      | 1 bit   | Reset assíncrono, ativo em nível baixo |
| `btn[3:0]` | 4 bits  | Botões de entrada |

**Mapeamento dos botões:**

| `btn`  | Cor         |
|--------|-------------|
| `0001` | 🔵 Azul     |
| `0010` | 🟡 Amarelo  |
| `0100` | 🟢 Verde    |
| `1000` | 🔴 Vermelho |

### Saída

| Sinal    | Largura | Descrição |
|----------|---------|-----------|
| `unlock` | 1 bit   | `1` quando o cofre está desbloqueado |

---

## 🔢 Sequência Correta

```
🔵 AZUL  →  🟡 AMARELO  →  🟡 AMARELO  →  🔴 VERMELHO
```

Qualquer entrada fora desta sequência retorna o sistema ao estado `INIT`.

---

## 🧠 Estrutura da FSM

### Estados (codificação one-hot)

| Estado     | Código      | `unlock` | Descrição |
|------------|-------------|:--------:|-----------|
| `INIT`     | `5'b00001`  | `0`      | Estado inicial / erro — aguarda primeiro botão |
| `BLUE`     | `5'b00010`  | `0`      | Azul pressionado corretamente |
| `YELLOW_1` | `5'b00100`  | `0`      | Primeiro amarelo pressionado corretamente |
| `YELLOW_2` | `5'b01000`  | `0`      | Segundo amarelo pressionado corretamente |
| `UNLOCKED` | `5'b10000`  | `1`      | Sequência completa — cofre desbloqueado |

### Regras de Transição

- ✅ Botão correto → avança para o próximo estado
- ❌ Botão errado → retorna para `INIT`
- ❌ Mais de um botão simultâneo → retorna para `INIT` (validado por `$onehot`)
- ⏸️ Nenhum botão → mantém estado atual
- 🔓 `UNLOCKED` permanece até reset assíncrono

---

## 📊 Diagrama de Estados

![Diagrama de Estados](images/diagrama_fsm.png)

> A linha de divisão horizontal dentro de cada estado separa o nome (topo) da saída `unlock` (base), conforme o padrão de representação de máquinas Moore.  
> Setas tracejadas em vermelho indicam transições de erro que retornam ao `INIT`.

---

## 💻 Código — `src/safecrack.sv`

```systemverilog
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
```

---

## ⚙️ Principais Conceitos Utilizados

| Conceito | Aplicação no Projeto |
|----------|----------------------|
| `typedef enum` | Definição legível dos cinco estados da FSM |
| `always_ff` | Dois blocos: registro de estado e captura de `btn_old` |
| `always_comb` + `unique case` | Lógica de próximo estado com aviso de casos não cobertos |
| One-hot encoding | `5'b00001` a `5'b10000` — otimiza roteamento em FPGA |
| Edge detection | `btn_old` detecta a borda de subida do botão |
| `$onehot()` | Garante exatamente um bit ativo — rejeita entradas inválidas |
| FSM Moore | `unlock` depende apenas do estado atual, não das entradas |

---

## 🔄 Detecção de Borda (Edge Detection)

O sistema detecta apenas o **momento exato do clique**, evitando múltiplas transições enquanto o botão permanece pressionado:

```systemverilog
assign event_valid = (btn != 4'b0000) && (btn_old == 4'b0000);
assign btn_onehot  = $onehot(btn);
```

`event_valid` só é verdadeiro no ciclo em que o botão passa de `0000` para qualquer valor diferente de zero. `btn_onehot` verifica que exatamente um bit está ativo.

---

## 🔓 Lógica de Saída (Moore)

```systemverilog
assign unlock = (state == UNLOCKED);
```

A saída depende **exclusivamente do estado atual**, característica fundamental das máquinas Moore — o que garante estabilidade e ausência de glitches na saída.

---

## 🚨 Tratamento de Erros

| Situação | Comportamento |
|----------|---------------|
| Botão errado pressionado | Retorna para `INIT` |
| Mais de um botão simultâneo | Retorna para `INIT` (via `$onehot`) |
| Nenhum botão pressionado | Mantém o estado atual |
| `UNLOCKED` atingido | Permanece até reset assíncrono (`rst = 0`) |

---

## 👥 Integrantes

| Nome          | E-mail               |
|---------------|----------------------|
| Caio Agrelli  | caarr@cin.ufpe.br    |
| Lucas David   | ldlf@cin.ufpe.br     |
| João Gustavo  | jggp@cin.ufpe.br     |


---

## 🏫 Contexto Acadêmico

| Campo       | Informação                                               |
|-------------|----------------------------------------------------------|
| Disciplina  | Laboratório de Organização e Arquitetura de Computadores |
| Instituição | Centro de Informática – UFPE (CIn)                       |
| Professores | Edna Barros e Victor Medeiros                            |
| Linguagem   | SystemVerilog (HDL)                                      |
| Ano         | 2026                                                     |
