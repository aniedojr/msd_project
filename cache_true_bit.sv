 
////////////////////////////////////////////////////////////////////////
// cache_true_bit.sv
//
// 
//
// Description:
// This module takes the provided input address trace as its input.
// It  will implement the workings of the cache. 
// Specifically, it will keep track of which blocks are
// brought into the cache and which blocks are being evicted. 
// At the completion of the trace, the simulator will provide 
// statistics about cache hit ratio, read traffic, write traffic, etc.
////////////////////////////////////////////////////////////////////////
module cache 
  #(parameter num_sets           = 32  , // total number of sets
    parameter num_ways           = 8 	, // associatvity           range(1 to 8)
    parameter line_size          = 64	, // line size (in bytes)   range(32 to 128)
    parameter replacement_policy = 0     // replacement policy     0 = True LRU
                                          //                        1 = 1-bit LRU
   )(
    input clk,
    input logic[1:0] Access_type,              // read=0, write=1, invalidate=2
    input [31:0] Hex_address              // requested address
);

// bits required for each parameter
localparam LINE_SIZE 		= line_size*8;
localparam NUM_SETS_SIZE 	= $clog2(num_sets);
//localparam ASSOCIAVITY_SIZE	= $clog2(num_ways);

localparam ADDRESS_SIZE		= 32;
localparam BYTE_SELECT_SIZE 	= $clog2(line_size);
localparam INDEX_SIZE		= NUM_SETS_SIZE;
localparam TAG_SIZE		= ADDRESS_SIZE - INDEX_SIZE - BYTE_SELECT_SIZE;

// operations
localparam READ 		= 0;
localparam WRITE		= 1;
localparam INVALIDATE 		= 2;

// cache memory
bit				valid          	[num_sets][num_ways];
bit 				dirty		[num_sets][num_ways];
bit [TAG_SIZE-1:0]		tag_array	[num_sets][num_ways];
int 				aj		[num_sets][num_ways];
// requested address
logic [TAG_SIZE-1:0]		tag;
logic [INDEX_SIZE-1:0] 		index;
logic [BYTE_SELECT_SIZE-1:0]	byte_select;

// statistics
int total_number_of_cache_accesses = 0;	// Total number of cache accesses
int number_of_cache_reads = 0; 		// Number of cache reads
int number_of_cache_writes = 0;		// Number of cache writes
int number_of_invalidates = 0;		// Number of invalidates
int number_of_cache_hits = 0;		// Number of cache hits
int number_of_cache_misses = 0;		// Number of cache misses
real cache_hit_ratio = 0;		// Cache hit ratio
real cache_miss_ratio = 0;		// Cache miss ratio
int number_of_evictions = 0;		// Number of evictions
int number_of_writebacks = 0;		// Number of writebacks


//temp_variables
int i, j;
logic chit_r;
logic chit_w;
logic mflag_r; 
logic mflag_w; 
logic mflag_i;
int rep_r, rep_w;
int temp_r, k_r;
int temp_w, k_w;
int temp_i, k_i;
bit sum_r, sum_w;
int rep_fr, rep_fw;
int mindex_r,mindex_w, mindex_i;
bit valid_orr, valid_andr;
bit valid_orw, valid_andw;
int z_r,z_w;

  always@(posedge clk)
begin
  // format address
  {tag, index, byte_select} = Hex_address;

  // Hit Ratio =  HitNumber of cache hits / Number of cache accesses
 // cache_hit_ratio = real'(number_of_cache_hits)/(real'(total_number_of_cache_accesses))*100.00;
  j = index;
  $display($time,"INSIDE THE ALWAYS BLOCK  AND ACCESS TYPE= %d//%d//%b",Access_type,j,index);

if(Access_type==0) //read trace access type
	begin 
	total_number_of_cache_accesses++;
cache_read();
end

else if(Access_type==1)
	begin  
	total_number_of_cache_accesses++;
	cache_write();
end

else if(Access_type==2)
	begin		
        cache_invalidate();
	end
end


function void cache_read();
  mflag_r=0;
  chit_r=1;
  rep_fr=0;
  valid_orr=1;
  valid_andr=1;
  sum_r=0;
$display($time,"INSIDE THE READ ACCESS  AND ACCESS TYPE= %d",Access_type);
number_of_cache_reads++; 
	//first we will check for cache hit
  	   for(i=0; i<num_ways; i++)	//from left to right the cache lines are scanned for matching tags for associative case
  	   begin
		if ((tag_array[j][i]==tag) && (valid[j][i]==1))	//checks for valid bits 1 and tags matching
		begin
			$display($time,"ITS A READ tag hit" );
			rep_fr=1;
	  		number_of_cache_hits++;	
	  		for(k_r=0; k_r<num_ways; k_r++)	//to check whether the cache line accessed was in the access array.. it will be there as it is a cache hit!!
	  		begin
				if(aj[j][k_r]==i+1)
				begin
				$display($time,"FLAG HIGH PROCEDURE//%d//%d//%d",i,k_r,aj[j][k_r] );
					mflag_r=1;
					mindex_r=k_r;
				end
	 		end
	  		if(mflag_r==1)
	 		begin
				$display($time,"for READ THIS CACHE LINE IS ACCESSED//%d//%d//%d", aj[j][0],aj[j][1],mindex_r,j );
				temp_r=mindex_r;
				for(k_r=0; k_r<mindex_r;k_r++)
				begin
				$display($time,"INSIDE READ FLAG IS HIGH//%d//%d//%d",temp_r,mindex_r,k_r );
					aj[j][temp_r]=aj[j][temp_r-1];
					temp_r--;
				end
				aj[j][0]=i+1;
	  		end
			chit_r=0;
			break;
		end
	   end
  //((valid[j][0]==0) || (valid[j][1]==0) || (valid[j][2]==0) || (valid[j][3]==0) || (valid[j][4]==0) || (valid[j][5]==0) || (valid[j][6]==0) || (valid[j][7]==0))
  for(i=0; i<num_ways; i++)
                begin
                  valid_orr=valid_orr && valid[j][i];
                 end
  if(valid_orr==0)
	begin
		$display($time,"INSIDE READ MISS CHECK VALID ZERO" );
		 rep_fr=1;
		for(i=0;i<num_ways;i++)
		begin
			if((valid[j][i]==0) && chit_r)
			begin
				$display($time,"INSIDE READ VALID IS ZERO" );
				number_of_cache_misses++;
				valid[j][i]=1;
				dirty[j][i]=0;
				tag_array[j][i]=tag;
				for (z_r=0;z_r<num_ways;z_r++)
				begin
				sum_r=aj[j][z_r] || sum_r; //CHANGE FOR ASSOCIATIVITY
				end
				if(sum_r==0)
				begin
					$display($time,"FIRST LOCATION FILLED//VERY FIRST CACHE MISS//READ//%d",sum_w );
					aj[j][0]=i+1;
                  break;
				  $display($time,"MUST BREAK//PROBLEM IF DIDN'T BREAK" );
				end
				else
				begin
					for(k_r=0; k_r<num_ways; k_r++)
					begin
						if(aj[j][k_r]==0)
						begin
						$display($time,"NOT A FIRST LOCATION FILLED//CACHE MISS//READ" );
							mflag_r=1;
							mindex_r=k_r;
							$display($time,"BEFORE BREAK HAPPENS" );
							break;
						end
					end
					if(mflag_r==1)
					$display($time,"RECENCY ARRAY READ//%d//%d",mindex_w);
					begin
						temp_r=mindex_r;
						for(k_r=0; k_r<mindex_r;k_r++)
						begin
							aj[j][temp_r]=aj[j][temp_r-1];
							temp_r--;
						end
						aj[j][0]=i+1;
					end
					break;
				end
			end
		end
	end
	else if(rep_fr==1)
    begin
      $display($time,"REPLACEMENT CANNOT BE TRIGGERED for READ");
    end
	else begin
	//if((valid[j][0]==1) && (valid[j][1]==1) && (valid[j][2]==1) && (valid[j][3]==1) && (valid[j][4]==1) && (valid[j][5]==1) && (valid[j][6]==1) && (valid[j][7]==1)) //CHANGES
	//begin
	for(i=0; i<num_ways; i++)
                begin
					 valid_andr=valid_andr && valid[j][i];
                end
		//if(chit_r==1)	
        if(valid_andr==1)
		begin
          $display($time,"REPLACEMENT POLICY STARTED//%d//%d//%d", rep_r,aj[j][num_ways-1],num_ways );
	          rep_r= aj[j][num_ways-1]-1;
		  $display($time,"REPLACEMENT POLICY STARTED//%d//%d//%d", rep_r,aj[j][num_ways-1],num_ways );
			if(dirty[j][rep_r]==1)
			begin
			$display($time,"READ REPLACEMENT WRITEBACK//%d//%d//%b", rep_r, j, dirty[j][rep_r] );
				number_of_writebacks++;
				number_of_evictions++;
				number_of_cache_misses++;
				valid[j][rep_r]=1;
				dirty[j][rep_r]=0;
				tag_array[j][rep_r]=tag;
				aj[j][num_ways-1]=0;
				temp_r=num_ways-1;
				for(k_r=0;k_r<num_ways-1;k_r++)
				begin
					aj[j][temp_r]=aj[j][temp_r-1];
					temp_r--;
				end
				aj[j][0]=rep_r+1;
				$display($time,"AFTER REPLACEMENT //%d//%d//%d//%d//%d//%d//%d//%d", aj[j][0], aj[j][1], aj[j][2], aj[j][3], aj[j][4], aj[j][5], aj[j][6], aj[j][7]);
			end
			else
			begin
			$display($time,"READ REPLACEMENT NO WRITEBACK//%d//%d//%b", rep_r, j, dirty[j][rep_r] );
				number_of_evictions++;
				number_of_cache_misses++;
				valid[j][rep_r]=1;
				dirty[j][rep_r]=0;
				tag_array[j][rep_r]=tag;
				aj[j][num_ways-1]=0;
				temp_r=num_ways-1;
				for(k_r=0;k_r<num_ways-1;k_r++)
				begin
					aj[j][temp_r]=aj[j][temp_r-1];
					temp_r--;
				end
				aj[j][0]=rep_r+1;
			$display($time,"AFTER REPLACEMENT //%d//%d//%d//%d//%d//%d//%d//%d", aj[j][0], aj[j][1], aj[j][2], aj[j][3], aj[j][4], aj[j][5], aj[j][6], aj[j][7]);
			end
		end

	end

endfunction

function void cache_write();
  mflag_w=0;
  chit_w=1;
  rep_fw=0;
  valid_orw=1;
  valid_andw=1;
  sum_w=0;
$display("INSIDE THE WRITE BLOCK  AND ACCESS TYPE= %d",Access_type);
number_of_cache_writes++;


//CACHE WRITE ARE CHECKED FIRST
  for(i=0; i<num_ways; i++)
  begin
	if ((tag_array[j][i]==tag) && (valid[j][i]==1))
	begin
      $display($time,"ITS A WRITE tag hit" );
	  dirty[j][i]=1;
	rep_fw=1;
	number_of_cache_hits++;
	for(k_w=0; k_w<num_ways; k_w++)
	begin
      
//INSIDE CACHE HIT BLOCK
//NOW CACHE RECENCY WILL BE FILLED IN THE RECENCY ARRAY
      if(aj[j][k_w]==(i+1))
		begin
          $display($time,"FLAG HIGH PROCEDURE  RECENCY FOR WRITE //%d//%d//%d",i,k_w,aj[j][k_w] );
			mflag_w=1;
			mindex_w=k_w;
		end
	end
 //THE RECENCY ARRAY INFO OF mindex and flag is taken     
	if(mflag_w==1)
	begin
      $display($time,"for WRITE THIS CACHE LINE IS ACCESSED//%d//%d//%d", aj[j][0],aj[j][1],mindex_w,j );
		temp_w=mindex_w;
		for(k_w=0; k_w<mindex_w;k_w++)
		begin
          $display($time,"RECENCY SHIFTS FOR WRITE//%d//%d//%d",temp_w,mindex_w,k_w );
//THE RECENCY ARRAY SHIFTS ARE DONE HERE
			aj[j][temp_w]=aj[j][temp_w-1];
			temp_w--;
		end
		aj[j][0]=i+1;
      $display($time,"AFTER SHIFTS FOR HIT//%d//%d//%d//%d//%d//%d//%d//%d", aj[j][0], aj[j][1], aj[j][2], aj[j][3], aj[j][4], aj[j][5], aj[j][6], aj[j][7]);
	end
	chit_w=0;
	break;
	end 
  end
// THE WRITE CACHE MISS BLOCK FOR FILLING ZERO COMPARTMENTS		
  //if((valid[j][0]==0) || (valid[j][1]==0) || (valid[j][2]==0) || (valid[j][3]==0) || (valid[j][4]==0) || (valid[j][5]==0) || (valid[j][6]==0) || (valid[j][7]==0))	
	//begin
	for(i=0; i<num_ways; i++)
                begin
                  valid_orw=valid_orw && valid[j][i];                  
                end
  if(valid_orw==0)
  begin
  $display($time,"INSIDE WRITE MISS CHECK VALID ZERO" );
		 rep_fw=1;
		for(i=0;i<num_ways;i++)
		begin
          if((valid[j][i]==0) && chit_w)
			begin
              $display($time,"INSIDE WRITE VALID IS ZERO" );
//FOUND THE ZERO COMPARTMENT
			number_of_cache_misses++;
			valid[j][i]=1;
			dirty[j][i]=1;
			tag_array[j][i]=tag;
			for (z_w=0;z_w<num_ways;z_w++)
				begin
				sum_w=aj[j][z_w] || sum_w; //CHANGE FOR ASSOCIATIVITY
			end
			if(sum_w==0)
              begin
                $display($time,"FIRST LOCATION FILLED//VERY FIRST CACHE MISS//WRITE//%d",sum_w );
//RECENCY WILL BE FILLED FOR FIRST COMPARTMENT  ONLY
                aj[j][0]=i+1;
              break;
                $display($time,"MUST BREAK" );
              end
			else
			begin
//FIRST LOCATION MISSED SO NOT A POWER ON SITUATION
              for(k_w=0; k_w<num_ways; k_w++)
						begin
//RECENCY ARRAY FILLING STARTED FOR FIRST LOCATION MISS
								if(aj[j][k_w]==0)
								begin
                                  $display($time," NOT A FIRST LOCATION FILLED//CACHE MISS//WRITE" );
									mflag_w=1;
									mindex_w=k_w;
                                  $display($time,"BEFORE BREAK HAPPENS//%d//%d",mindex_w,k_w );
                                  break;
								end
                          end
						if(mflag_w==1)
							begin
								temp_w=mindex_w;
                              $display($time,"RECENCY ARRAY//%d//%d//%d",temp_w,k_w,mindex_w);
                              for(k_w=0; k_w<mindex_w;k_w++)
								begin
									aj[j][temp_w]=aj[j][temp_w-1];
									temp_w--;
                                end
								aj[j][0]=i+1;
                              $display($time,"BREAK//CACHE MISS//WRITE//%d//%d//%d//%d//%d//%d//%d//%d", aj[j][0], aj[j][1], aj[j][2], aj[j][3], aj[j][4], aj[j][5], aj[j][6], aj[j][7]);
							end
							break;
			end
			end
		end
//REPLACEMENT TRIGGERING BLOCK
end
  else if(rep_fw==1)
    begin
      $display($time,"REPLACEMENT CANNOT BE TRIGGERED");
    end
  	else
   	 begin 
    //if((valid[j][0]==1) && (valid[j][1]==1) && (valid[j][2]==1) && (valid[j][3]==1) && (valid[j][4]==1) && (valid[j][5]==1) && (valid[j][6]==1) && (valid[j][7]==1))
	//begin
	for(i=0; i<num_ways; i++)
                begin
                  valid_andw=valid_andw && valid[j][i];                  
                end
	if(valid_andw==1)
	begin
	$display($time,"REPLACEMENT TRIGGERED//CACHE MISS//WRITE" );
      if(chit_w==1)
	begin
      rep_w= aj[j][num_ways-1]-1;
      $display($time,"REPLACEMENT POLICY STARTED//%d//%d//%d//%b", rep_w,aj[j][num_ways-1],num_ways, dirty[j][rep_w] );
		if(dirty[j][rep_w]==1)
		begin
          $display($time,"REPLACEMENT WRITEBACK//%d//%d//%b", rep_w, j, dirty[j][rep_w] );
			number_of_writebacks++;
			number_of_evictions++;
			number_of_cache_misses++;
			valid[j][rep_w]=1;
			dirty[j][rep_w]=1;
			tag_array[j][rep_w]=tag;
			aj[j][num_ways-1]=0;
			temp_w=num_ways-1;
			for(k_w=0;k_w<num_ways-1;k_w++)
				begin
				aj[j][temp_w]=aj[j][temp_w-1];
				temp_w--;
				end
          aj[j][0]=rep_w+1;
          $display($time,"AFTER REPLACEMENT WITH DIRTY //%d//%d//%d//%d//%d//%d//%d//%d", aj[j][0], aj[j][1], aj[j][2], aj[j][3], aj[j][4], aj[j][5], aj[j][6], aj[j][7]);
		end
		else
		begin
          $display($time," NO REPLACEMENT WRITEBACK//%d//%d//%b", rep_w, j, dirty[j][rep_w] );
			number_of_evictions++;
			number_of_cache_misses++;
			valid[j][rep_w]=1;
          dirty[j][rep_w]=1;
			tag_array[j][rep_w]=tag;
			aj[j][num_ways-1]=0;
			temp_w=num_ways-1;
			for(k_w=0;k_w<num_ways-1;k_w++)
				begin
				aj[j][temp_w]=aj[j][temp_w-1];
				temp_w--;
				end
          aj[j][0]=rep_w+1;
		end
	end
end
     end

endfunction

function void cache_invalidate();
number_of_invalidates++;
mflag_i=0;
for(i=0;i<num_ways;i++)
begin
			if(tag_array[j][i]==tag)
			begin
				valid[j][i]=0;
				dirty[j][i]=0;
				tag_array[j][i]=0;
              $display($time," TAG MATCH INVALIDATE//%d", i );
//RECENCY ARRAY FILLING STARTED FOR FIRST LOCATION MISS
              for(k_i=0; k_i<num_ways;k_i++)
						begin
                          if(aj[j][k_i]==(i+1))
								begin
                                  $display($time," NOT A FIRST LOCATION FILLED//CACHE MISS//WRITE" );
									mflag_i=1;
									mindex_i=k_i;
                                  $display($time,"BEFORE BREAK HAPPENS//%d//%d",mindex_i,k_i );
								end
                        end
						if(mflag_i==1)
						begin
								temp_i=mindex_i;
								$display($time,"RECENCY ARRAY//%d//%d//%d",temp_i,k_i,mindex_i);
								for(k_i=0; k_i<mindex_i;k_i++)
								begin
									aj[j][temp_i]=aj[j][temp_i-1];
									temp_i--;
                                end
								aj[j][0]=0;
                              $display($time,"BREAK//CACHE MISS//WRITE//%d//%d//%d//%d//%d//%d//%d//%d", aj[j][0], aj[j][1], aj[j][2], aj[j][3], aj[j][4], aj[j][5], aj[j][6], aj[j][7]);
						end
						break;
			end
end
endfunction

endmodule
