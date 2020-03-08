// Code your design here
  
////////////////////////////////////////////////////////////////////////
// cache.sv
//
// Team Members: Kaviya Ramachandran, Saurabh Chavan, Ariel Niedo
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
    input Access_type,              // read=0, write=1, invalidate=2
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
bit				mru          	[num_sets][num_ways];
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
int rep_r, rep_w;
int temp_r, k_r;
int temp_w, k_w;
int sum_r, sum_w;
bit rep_fr, rep_fw;
int mindex_r,mindex_w;
bit MRUAND_r,MRUAND_w;

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
  chit_r=1;
  rep_fr=0;
  MRUAND_r = 1;
$display($time,"INSIDE THE READ ACCESS  AND ACCESS TYPE= %d",Access_type);
number_of_cache_reads++; 
/////////11111111111//////////
	//first we will check for cache hit
  	   for(i=0; i<num_ways; i++)	//from left to right the cache lines are scanned for matching tags for associative case
  	   begin
		if ((tag_array[j][i]==tag) && (valid[j][i]==1))	//checks for valid bits 1 and tags matching
		begin
			$display($time,"ITS A READ tag hit" );
			chit_r=0; //FLAG FOR NOT EXECUTING THE CACHE MISS BLOCK AS CACHE HIT WAS ACCESSED
			rep_fr=1; //FLAG FOR NOT EXECUTING THE CACHE MISS BLOCK REPLACEMENT BLOCK AS CACHE HIT WAS ACCESSED
			number_of_cache_hits++;	
			$display($time,"READ tag hit PARAMETERS//%b",mru[j][i] );
			break;
		end
	   end
////////////22222222222///////////	   
  if((valid[j][0]==0) || (valid[j][1]==0) || (valid[j][2]==0) || (valid[j][3]==0) || (valid[j][4]==0) || (valid[j][5]==0) || (valid[j][6]==0) || (valid[j][7]==0))
	begin
		$display($time,"INSIDE READ MISS CHECK VALID ZERO" );
		 rep_fr=1; //FLAG FOR NOT EXECUTING THE CACHE MISS BLOCK REPLACEMENT BLOCK AS CACHE HIT WAS ACCESSED
		for(i=0;i<num_ways;i++)
		begin
			if((valid[j][i]==0) && chit_r)
			begin
				$display($time,"READ MISS valid zero//%b//%d", rep_fr,i );
				$display($time,"INSIDE READ VALID IS ZERO COMPARTMENT" );
				number_of_cache_misses++;
				valid[j][i]=1;
				dirty[j][i]=0;
				tag_array[j][i]=tag;
				mru[j][i]=1;
				$display($time,"READ MISS valid zero//%b", rep_fr );
				break;
			end
		end
    end
////////////333333333333//////////			
		//REPLACEMENT POLICY GETS TRIGGERED IF (rep_fr==1)
		else if(rep_fr==0)
		begin
			if((valid[j][0]==1) && (valid[j][1]==1) && (valid[j][2]==1) && (valid[j][3]==1) && (valid[j][4]==1) && (valid[j][5]==1) && (valid[j][6]==1) && (valid[j][7]==1) )
			begin
			$display($time,"REPLACEMENT POLICY TRIGGERED FOR READ//%b", rep_fr );
			//SCANNING ALL MRU BITS TO SEE IF THE MRU BITS ARE SET TO 1
			for(i=0;i<num_ways;i++) 
			begin
				MRUAND_r=mru[j][i] && MRUAND_r;
			end
			$display($time,"MRUAND_r value is//%b", MRUAND_r );
			//MRU BITS = 1 CONDITION
			if(MRUAND_r==1)
			begin
			$display($time,"ALL MRU BITS ARE ONES");
				//SETTING ALL MRU BITS TO 0
				for(i=0;i<num_ways;i++) 
				begin
					mru[j][i]=0;
				end
              $display($time,"ALL MRU BITS ARE MADE ZEROES//%b//%b//%b//%b", mru[j][0], mru[j][1]);
            if(dirty[j][0]==1)
				begin
			$display($time,"DIRTY BIT READ 1 ENTERED");
					valid[j][0]=1;
					tag_array[j][0]=tag;
					mru[j][0]=1;
                  	dirty[j][0]=0;
					number_of_writebacks++;
					number_of_evictions++;
					number_of_cache_misses++;
                  $display($time,"FIRST LOCATION IS FILLED//%b",mru[j][0]);
				end
				else
				begin
				$display($time,"DIRTY BIT READ 0 ENTERED");
					valid[j][0]=1;
					tag_array[j][0]=tag;
					mru[j][0]=1;
					number_of_evictions++;
					number_of_cache_misses++;
				$display($time,"FIRST LOCATION IS FILLED//%b",mru[j][0]);
				end
			end

			//NOT ALL MRU BITS = 1 CONDITION
			else if(MRUAND_r==0)
			begin
			$display($time,"ALL MRU BITS ARE NOT ONES//%b",mru[j][0]);
              for(i=0;i<num_ways;i++)
				begin
                  if(mru[j][i]==0)
					begin
					mindex_r=i;
                    $display($time,"THIS COMPARTMENT IS ZERO FOR MRU//%d//%d//%b",mindex_r,i,dirty[j][0] );
                  break;
					end
				end
				if(dirty[j][mindex_r]==1)
				begin
                  $display($time,"FIRST LOCATION FOR FIRST MRU//%b",mru[j][0]);
				$display($time,"DIRTY BIT READ 1 ENTERED//%b",dirty[j][mindex_r]);
                  valid[j][mindex_r]=1;
                  tag_array[j][mindex_r]=tag;
                  mru[j][mindex_r]=1;
                  dirty[j][mindex_r]=0;
					number_of_writebacks++;
					number_of_evictions++;
					number_of_cache_misses++;
				$display($time,"MRU BIT ZERO LOCATION FILLED",dirty[j][mindex_r]);
				end
				else
				begin
				$display($time,"DIRTY BIT READ 0 ENTERED//%b",dirty[j][mindex_r]);
                  valid[j][mindex_r]=1;
                  tag_array[j][mindex_r]=tag;
                  mru[j][mindex_r]=1;
				number_of_evictions++;
				number_of_cache_misses++;
				$display($time,"MRU BIT ZERO LOCATION FILLED//%b",dirty[j][mindex_r]);
				end
			end
		end
	end
endfunction

function void cache_write();
  chit_w=1;
  rep_fw=0;
  MRUAND_w=1;
$display("INSIDE THE WRITE BLOCK  AND ACCESS TYPE= %d",Access_type);
number_of_cache_writes++;
//CACHE WRITE ARE CHECKED FIRST
/////////11111111111///////////
	//first we will check for cache hit
  	   for(i=0; i<num_ways; i++)	//from left to right the cache lines are scanned for matching tags for associative case
  	   begin
		if ((tag_array[j][i]==tag) && (valid[j][i]==1))	//checks for valid bits 1 and tags matching
		begin
			$display($time,"ITS A WRITE tag hit" );
          	dirty[j][i]=1;
			chit_w=0; //FLAG FOR NOT EXECUTING THE CACHE MISS BLOCK AS CACHE HIT WAS ACCESSED
			rep_fw=1; //FLAG FOR NOT EXECUTING THE CACHE MISS BLOCK REPLACEMENT BLOCK AS CACHE HIT WAS ACCESSED
			number_of_cache_hits++;	
			$display($time,"WRITE tag hit PARAMETERS//%b",mru[j][i] );
			break;
		end
	   end
////////222222222/////////	   
  if((valid[j][0]==0) || (valid[j][1]==0) || (valid[j][2]==0) || (valid[j][3]==0) || (valid[j][4]==0) || (valid[j][5]==0) || (valid[j][6]==0) || (valid[j][7]==0))
	begin
		$display($time,"INSIDE WRITE MISS CHECK VALID ZERO" );
		 rep_fw=1; //FLAG FOR NOT EXECUTING THE CACHE MISS BLOCK REPLACEMENT BLOCK AS CACHE HIT WAS ACCESSED
		for(i=0;i<num_ways;i++)
		begin
			if((valid[j][i]==0) && chit_w)
			begin
				$display($time,"WRITE MISS valid zero//%b//%d", rep_fw,i );
				$display($time,"INSIDE WRITE VALID IS ZERO COMPARTMENT" );
				number_of_cache_misses++;
				valid[j][i]=1;
              	dirty[j][i]=1;
				tag_array[j][i]=tag;
				mru[j][i]=1;
				$display($time,"READ MISS valid zero//%b", rep_fw );
				break;
			end
		end
    end
////////////3333333333//////////			
		//REPLACEMENT POLICY GETS TRIGGERED IF (rep_fw==1)
		else if(rep_fw==0)
		begin
			if((valid[j][0]==1) && (valid[j][1]==1) && (valid[j][2]==1) && (valid[j][3]==1) && (valid[j][4]==1) && (valid[j][5]==1) && (valid[j][6]==1) && (valid[j][7]==1))
			begin
		$display($time,"REPACEMENT POLICY TRIGGERED FOR WRITE//%b", rep_fw );
			//SCANNING ALL MRU BITS TO SEE IF THE MRU BITS ARE SET TO 1
			for(i=0;i<num_ways;i++) 
			begin
				MRUAND_w=mru[j][i] && MRUAND_w;
			end
			$display($time,"MRUAND_w value is//%b", MRUAND_w );
			//MRU BITS = 1 CONDITION
			if(MRUAND_w==1)
			begin
			$display($time,"ALL MRU BITS ARE ONES");
			//SETTING ALL MRU BITS TO 0
				for(i=0;i<num_ways;i++) 
				begin
					mru[j][i]=0;
				end
		$display($time,"ALL MRU BITS ARE MADE ZEROES//%b//%b//%b//%b", mru[j][0], mru[j][1] );
				if(dirty[j][0]==1)
				begin
				$display($time,"DIRTY BIT WRITE 1 ENTERED");
					valid[j][0]=1;
					tag_array[j][0]=tag;
					mru[j][0]=1;
					number_of_writebacks++;
					number_of_evictions++;
					number_of_cache_misses++;
					$display($time,"MRU BIT ZERO LOCATION FILLED",dirty[j][mindex_r]);
				end
				else
				begin
                  //$display($time,"ALL MRU BITS ARE NOT ONES");//
					valid[j][0]=1;
					tag_array[j][0]=tag;
					mru[j][0]=1;
                  	dirty[j][0]=1;
					number_of_evictions++;
					number_of_cache_misses++;
                  //$display($time,"MRU BIT ZERO LOCATION FILLED",dirty[j][0]);//
				end
			end
		//NOT ALL MRU BITS = 1 CONDITION
			else if(MRUAND_w==0)
			begin
				for(i=0;i<num_ways;i++)
				begin
					if(mru[j][i]==0)
					begin
						mindex_w=i;
                    break;
					end
				end
              $display($time,"THIS COMPARTMENT IS ZERO FOR MRU//%d//%d",mindex_w,i );//
				if(dirty[j][mindex_w]==1)
				begin
                 // $display($time,"DIRTY BIT WRITE 1 ENTERED//%b",dirty[j][mindex_w]);//
                  	valid[j][mindex_w]=1;
                 	tag_array[j][mindex_w]=tag;
                  	mru[j][mindex_w]=1;
					number_of_writebacks++;
					number_of_evictions++;
					number_of_cache_misses++;
					$display($time,"MRU BIT ZERO LOCATION FILLED",dirty[j][mindex_w]);
				end
				else
				begin
					$display($time,"DIRTY BIT WRITE 0 ENTERED//%b",dirty[j][mindex_w]);
                  	valid[j][mindex_w]=1;
                  	tag_array[j][mindex_w]=tag;
                  	mru[j][mindex_w]=1;
                  	dirty[j][mindex_w]=1;
					number_of_evictions++;
					number_of_cache_misses++;
					$display($time,"MRU BIT ZERO LOCATION FILLED//%b",dirty[j][mindex_w]);
				end
			end
		end
	end
endfunction

function void cache_invalidate();

for(i=0;i<num_ways;i++)
		begin
			if(tag_array[j][i]==tag)
			begin
				valid[j][i]=0;
				dirty[j][i]=0;
				tag_array[j][i]=0;
				mru[j][i]=0;
			end
			break;
		end

endfunction

endmodule
