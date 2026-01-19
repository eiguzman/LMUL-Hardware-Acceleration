`timescale 1ns / 1ps
module tb_lmul;
    // Parameters
    parameter N = 28;
    parameter M = 10;
    parameter BF16_WIDTH = 16;
    parameter NUM_TESTS = 1; // focus on one test image

    // Clock signals
    reg clk;
    reg rstn;

    // Inputs
    reg [BF16_WIDTH-1:0] i_a;
    reg [BF16_WIDTH-1:0] i_b;

    // Outputs
    wire [BF16_WIDTH-1:0] o_p;

    // Instantiate the multiplier
    lmul_bf16 dut (
        .clk(clk),
        .rstn(rstn),
        .i_a(i_a),
        .i_b(i_b),
        .o_p(o_p)
    );

    // Storage for input image and weights
    reg [BF16_WIDTH-1:0] input_image [0:N*N-1];
    reg [BF16_WIDTH-1:0] weights [0:M-1][0:N-1];

    // File handles
    integer f_img, f_wt;
    integer r, i, k;
    reg [15:0] word_buf; // for reading 16-bit data

    // Results array
    reg [BF16_WIDTH-1:0] results [0:NUM_TESTS-1][0:M-1];

    // FSM control
    reg [1:0] state;
    localparam STATE_IDLE=0, STATE_MUL=1, STATE_DONE=2;

    // Loop counters
    integer pixel_idx, m_idx;
    // Accumulators for each output neuron
    reg [31:0] accumulators [0:M-1];

    // Additional signals
    reg start_mul;
    wire done_mul;

    // For feeding inputs
    reg [15:0] current_pixel;
    reg [15:0] current_weight;

    // Generate clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock
    end

    // Read input image from binary file
    initial begin
        f_img = $fopen("input_image_0.bin", "rb");
        if (f_img == 0) begin
            $display("Error: Cannot open input_image_0.bin");
            $finish;
        end
        for (i=0; i<N*N; i=i+1) begin
            r = $fread(word_buf, f_img);
            if (r != 1) begin
                $display("Error reading input_image_0.bin at pixel %0d", i);
                $finish;
            end
            // Store as 16-bit value
            input_image[i] = word_buf;
        end
        $fclose(f_img);
    end

    // Read weights from binary file
    initial begin
        f_wt = $fopen("weights.bin", "rb");
        if (f_wt == 0) begin
            $display("Error: Cannot open weights.bin");
            $finish;
        end
        for (k=0; k<M*N; k=k+1) begin
            r = $fread(word_buf, f_wt);
            if (r != 1) begin
                $display("Error reading weights.bin at index %0d", k);
                $finish;
            end
            weights[k / N][k % N] = word_buf;
        end
        $fclose(f_wt);
    end

    // Main FSM for matrix-vector multiply
    initial begin
        // Wait until files are read
        wait($feof(f_img) == 0 && $feof(f_wt) == 0);
        // Initialize
        for (k=0; k<M; k=k+1)
            accumulators[k] = 0;
        state = STATE_IDLE;
        pixel_idx = 0;
        #1; // small delay to ensure file read complete
        state = STATE_MUL;
    end

    // Sequential process
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= STATE_IDLE;
            start_mul <= 0;
            for (k=0; k<M; k=k+1)
                accumulators[k] <= 0;
            pixel_idx <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    // Do nothing, wait for start
                end
                STATE_MUL: begin
                    if (pixel_idx < N*N) begin
                        // For each output neuron, multiply input pixel with weight and add
                        for (m_idx=0; m_idx<M; m_idx=m_idx+1) begin
                            current_pixel = input_image[pixel_idx];
                            current_weight = weights[m_idx][pixel_idx % N];

                            i_a <= current_pixel;
                            i_b <= current_weight;
                            start_mul <= 1;
                            @(posedge clk);
                            start_mul <= 0;

                            // Since multiplier is combinational, assume immediate output
                            // Accumulate the result
                            // Note: o_p is BF16, but for accumulation, sum BF16 directly or convert
                            // For simplicity, sum BF16 directly (though not precise)
                            accumulators[m_idx] <= accumulators[m_idx] + o_p;
                        end
                        pixel_idx = pixel_idx + 1;
                    end else begin
                        // All pixels processed
                        for (k=0; k<M; k=k+1)
                            results[0][k] = accumulators[k];
                        state = STATE_DONE;
                    end
                end
                STATE_DONE: begin
                    // Print results
                    $display("Results for test image:");
                    for (k=0; k<M; k=k+1) begin
                        $display("Neuron %0d: %04h", k, results[0][k]);
                    end
                    $finish;
                end
            endcase
        end
    end

    // Instantiate the multiplier
    lmul_bf16 u_multiplier (
        .clk(clk),
        .rstn(rstn),
        .i_a(i_a),
        .i_b(i_b),
        .o_p(o_p)
    );

    // Since the multiplier is combinational, generate a 'done' signal
    reg done_mul_reg;
    assign done_mul = 1; // always ready, as combinational

    // Optional: register the outputs for timing
    // But since your multiplier is combinational, no need

    // Reset sequence
    initial begin
        rstn = 0;
        #12;
        rstn = 1;
    end

endmodule
