
//////////////////////////////////////////////////////////////////
// tb.sv - Testbench for cache
// Team Members: Kaviya Ramachandran, Saurabh Chavan, Ariel Niedo
// Description:
// Reads a trace file line by line.
// Each line has an access type (0=read, 1=write, 2=invalidate) and 32-bit address.
// Simulation output statistics are shown at the end of simulation.
//
// Run instructions: 
// 1. Compile all then 
// 2. vsim -gui -voptargs=+acc work.tb; run -all; quit -sim
/////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
module tb();

logic clk=0;                // clock
//logic rst;                // reset 
int Access_type;  // access type 
logic [31:0] Hex_address=0; // 32-bit address
int fd;                   // file handle
parameter WORDS = 3;

  cache #(.num_sets(32), .num_ways(8), .line_size(64), .replacement_policy(0)) cache(
      .clk		(clk),
      //.rst		(rst),
      .Access_type	(Access_type),
      .Hex_address	(Hex_address)
);


// test cases

  always #50 clk=~clk;
  
initial begin
  // open test file
   
  fd = $fopen ("./trace.txt", "r");
  while (!$feof(fd)) begin
         $fscanf(fd, "%d %h", Access_type, Hex_address); 
    @(negedge clk) begin
 end
    end



  #20;
 $stop;
end


final begin
// simulator output: statistics

  /* EXAMPLE SIMULATOR OUTPUT FORMAT
  CACHE PARAMETERS
  Number of sets: 256
 

  #20 $finish();
end

final begin
// simulator output: statistics

  /* EXAMPLE SIMULATOR OUTPUT FORMAT
  CACHE PARAMETERS
  Number of sets: 256
  Associativity: 1
  Cache line size: 64
  Replacement policy: 1-bit LRU
  CACHE STATISTICS
  Total number of cache accesses: 512
  Number of cache reads: 256
  Number of cache writes: 256
  Number of invalidates: 0
  Number of cache hits: 128
  Number of cache misses: 384
  Cache hit ratio: 25.00%
  Cache miss ratio: 75.00%
  Number of evictions: 192
  Number of writebacks: 64
  */

$display("CACHE PARAMETERS");
$display("Number of sets: %0d", cache.num_sets);
$display("Associativity: %0d",  cache.num_ways);
$display("Cache line size: %0d", cache.line_size);

if(!cache.replacement_policy) $display("Replacement policy: True LRU");
else $display("Replacement policy: 1-bit LRU",);

$display("\nCACHE STATISTICS");
$display("Total number of cache accesses: %0d", cache.total_number_of_cache_accesses);
$display("Number of cache reads: %0d", cache.number_of_cache_reads);
$display("Number of cache writes: %0d", cache.number_of_cache_writes);
$display("Number of invalidates: %0d", cache.number_of_invalidates);
$display("Number of cache hits: %0d", cache.number_of_cache_hits);
$display("Number of cache misses: %0d", cache.number_of_cache_misses);
$display("Cache hit ratio: %3.2f%%", cache.cache_hit_ratio);
$display("Cache miss ratio: %3.2f%%", real'(100)-cache.cache_hit_ratio);
$display("Number of evictions: %0d", cache.number_of_evictions);
$display("Number of writebacks: %0d", cache.number_of_writebacks);
end

// instantiate cache

endmodule
