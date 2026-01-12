`timescale 1ns / 1ps
module tb_lmul;
    // Parameters
    parameter N = 28;
    parameter M = 10;
    parameter BF16_WIDTH = 16;
    parameter NUM_TESTS = 5; // match your number of images

    // Clock signals
    reg clk;
    reg rstn;

    // Inputs
    reg [BF16_WIDTH-1:0] i_a;
    reg [BF16_WIDTH-1:0] i_b;

    // Outputs
    wire [BF16_WIDTH-1:0] o_p;

    // Result storage
    reg [BF16_WIDTH-1:0] results [0:NUM_TESTS-1];
    reg [BF16_WIDTH-1:0] labels [0:NUM_TESTS-1]; // ground truth labels

    // Instantiate DUT
    top_lmul dut (
        .clk(clk),
        .rstn(rstn),
        .i_a(i_a),
        .i_b(i_b),
        .o_p(o_p)
    );

    // Internal arrays to hold input data
    reg [BF16_WIDTH-1:0] input_images [0:NUM_TESTS-1][0:N*N-1];
    reg [BF16_WIDTH-1:0] input_weights [0:M-1][0:N*N-1]; // One set of weights for all images

    // Indexes
    integer i, j, k;
    integer test_idx;

    // For loading files
    integer f_img, f_wt;
    integer r;

    initial begin
        // Generate clock
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    initial begin
        // Reset
        rstn = 0;
        i_a = 0;
        i_b = 0;
        #12; // wait some time
        rstn = 1;

        // Load input images
        for (i=0; i<NUM_TESTS; i=i+1) begin
            string filename;
            filename = $sformatf("input_image_%0d.bin", i);
            f_img = $fopen(filename, "rb");
            if (f_img == 0) begin
                $display("Error: Cannot open %s", filename);
                $finish;
            end
            for (j=0; j<N*N; j=j+1) begin
                r = $fread(input_images[i][j], f_img);
            end
            $fclose(f_img);
            // For ground truth labels, you can embed them here or load from a file
            // For simplicity, assuming you have label info
            // Set labels[i] accordingly (if known), or set to 0
            labels[i] = 16'h0000; // placeholder
        end

        // Load weights from file
        f_wt = $fopen("weights.bin", "rb");
        if (f_wt == 0) begin
            $display("Error: Cannot open weights.bin");
            $finish;
        end
        for (k=0; k<M*N; k=k+1) begin
            r = $fread({input_weights[k / N][k % N]}, f_wt);
        end
        $fclose(f_wt);

        // Run tests
        for (test_idx=0; test_idx<NUM_TESTS; test_idx=test_idx+1) begin
            // Apply input image pixels to i_a
            for (j=0; j<N*N; j=j+1) begin
                i_a = input_images[test_idx][j];
                i_b = input_weights[j / N][j % N];
                @(posedge clk);
            end

            // Wait one cycle for output
            @(posedge clk);
            results[test_idx] = o_p;
        end

        // Write results to CSV
        integer fout;
        fout = $fopen("results.csv", "w");
        if (fout == 0) begin
            $display("Error: Cannot open results.csv");
            $finish;
        end
        for (i=0; i<NUM_TESTS; i=i+1) begin
            $fwrite(fout, "%0d,%04h", i, results[i]);
            $display("Result %0d: %04h", i, results[i]);
        end
        $fclose(fout);
        $finish;
    end
endmodule
