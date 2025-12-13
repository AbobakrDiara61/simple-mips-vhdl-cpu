library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.ALL;

entity cpu is
 Generic (
	  Bit_Size : integer := 5;
	  pc_size : integer := 31
 );
 port(
  i_reset: in std_logic;
  i_clock: in std_logic;
  kit_clk: in std_logic;
  
  seven_segments : out STD_LOGIC_VECTOR (6 downto 0);
  anode       : out STD_LOGIC_VECTOR (1 downto 0);
  
  destnation_register : inout std_logic_vector(7 downto 0) := x"00"
 );
end cpu;

architecture behavioral of cpu is 
  -- signal section
  signal SF, ZF, CF: std_logic := '0';
	signal pc_signal : std_logic_vector(Bit_Size-1 downto 0) := (others => '0');
  signal accumulator_1 : std_logic_vector(7 downto 0) := x"00";
  signal accumulator_2 : std_logic_vector(7 downto 0) := x"00";
  -- Seven Segment signals
  signal refresh_counter : unsigned(16 downto 0) := (others => '0');
  signal mux_sel         : STD_LOGIC := '0';
  signal bcd_digit       : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
  signal tens_digit      : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
  signal ones_digit      : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
  
  -- computer system registers
  type Registers is array (0 to 7) of std_logic_vector(7 downto 0);
  signal R : Registers := (
    0 => "00000101",   -- 5
    1 => "00001000",   -- 8
    2 => "00001100",   -- 12
    3 => "00000110",   -- 6
    4 => "00010000",   -- 16
    5 => "00100100",   -- 36
    6 => "00001001",   -- 9
    7 => "00000100"    -- 4
  );

  -- Define ROM
  type ROM_Type is array (0 to 31) of std_logic_vector(15 downto 0);
  signal ROM : ROM_Type := (
    -- Instruction 0: R1 <- NSH (R1) which prints 8
    -- NSH is opcode 0000, shift_code 000, src1=R1, src2=don't care, dest=R1
    -- Format: opcode(4) shift_code(3) src1(3) src2(3) dest(3)
    0  => "0000000001000001", -- R1 <- NSH(R1) 
    
    -- Instruction 1: R1 <- R0 + R1
    -- ADD is opcode 0001, ALU code 000, src1=R0, src2=R1, dest=R1
    1  => "0001000000001001", -- R1 <- R0 + R1
    
    -- Instruction 2: if R1(13) > R1(8) then branch to address 3
    -- Branch if greater than is opcode 1111, target address=00011
    2  => "1111000000000011", -- Branch if R0 > R1 to addr 00011
    
    -- Instruction 3: R1 <- ZERO (R1)
    -- ZERO is opcode 0000, shift_code 001, src1=R1, src2=don't care, dest=R1
    3  => "0000001001010001", -- R1 <- ZERO(R1)
    
    -- Instruction 4: if ZF=1 then branch to address 7
    -- Branch LZ is opcode 1101, target address=00111
    4  => "1101000000000111", -- Branch if ZF=1 to addr 00111
    
    -- Instruction 5: R6 <- R5 - R4
    -- SUB is opcode 0001, ALU code 001, src1=R5, src2=R4, dest=R6
    5  => "0001001101100110", -- R6 <- R5 - R4
    
    -- Instruction 6: R2 <- R2 XOR R2
    -- XOR is opcode 0001, ALU code 110, src1=R2, src2=R2, dest=R2
    6  => "0001110010010010", -- R2 <- R2 XOR R2
    
    -- Instruction 7: R3 <- R7 * R3
    -- MUL is opcode 0001, ALU code 010, src1=R7, src2=R3, dest=R3
    7  => "0001010111011011", -- R3 <- R7 * R3
    
    -- Instruction 8: R1 <- R5 / R7
    -- DIV is opcode 0001, ALU code 011, src1=R5, src2=R7, dest=R1
    8  => "0001011101111001", -- R1 <- R5 / R7
    
    -- Instruction 9: if R1(9) > R7(4) then branch
    -- Branch if greater than is opcode 1111, target address=00000
    -- Need to specify target address - let's use addr 5 (00101)
    9  => "1111000000000101", -- Branch if R5 > R7 to addr 0101
    
    10 => x"0000",
    11 => x"0000",
    12 => x"0000",
    13 => x"0000",
    14 => x"0000",
    15 => x"0000",
    16 => x"0000",
    17 => x"0000",
    18 => x"0000",
    19 => x"0000",
    20 => x"0000",
    21 => x"0000",
    22 => x"0000",
    23 => x"0000",
    24 => x"0000",
    25 => x"0000",
    26 => x"0000",
    27 => x"0000",
    28 => x"0000",
    29 => x"0000",
    30 => x"0000",
    31 => x"0000"
  );

begin 
  process (i_reset, i_clock)
  variable pc_register : std_logic_vector(Bit_Size-1 downto 0);
  variable instruction_register : std_logic_vector(15 downto 0) := x"0000";
  variable temp_result: std_logic_vector(8 downto 0);
  variable temp_mul: std_logic_vector(15 downto 0);
  variable src_reg1_addr: std_logic_vector(2 downto 0);
  variable src_reg2_addr: std_logic_vector(2 downto 0);
  variable dest_reg_addr: std_logic_vector(2 downto 0);
  variable branch_target: std_logic_vector(4 downto 0);
  variable next_addr: std_logic := '1';
  variable op_code: std_logic_vector(3 downto 0);
  variable AC : std_logic_vector(7 downto 0) := x"00";
  variable MQ : std_logic_vector(7 downto 0) := x"00";
  variable shift_code: std_logic_vector(2 downto 0);
  variable memory_rw: std_logic := '0';

  variable store_addr : std_logic_vector(2 downto 0);
  begin
    if i_reset = '0' then
      -- reset
      accumulator_1 <= x"00";
      accumulator_2 <= x"00";
      pc_signal <= (others => '0');
      ZF <= '0';
      SF <= '0';
      CF <= '0';
      destnation_register <= x"00";	
      R <= (
        0 => "00000101",   -- 5
        1 => "00001000",   -- 8
        2 => "00001100",   -- 12
        3 => "00000110",   -- 6
        4 => "00010000",   -- 16
        5 => "00100100",   -- 36
        6 => "00001001",   -- 9
        7 => "00000100"    -- 4
      );
    elsif not(rising_edge(i_clock)) then	
      -- Update PC
		pc_register := pc_signal;
      -- Fetch instruction
      instruction_register := ROM(to_integer(unsigned(pc_register)));

      -- Extract info from IR 
      op_code := instruction_register(15 downto 12);
      shift_code := instruction_register(11 downto 9);
		src_reg1_addr := instruction_register(8 downto 6);  -- first source register
		src_reg2_addr := instruction_register(5 downto 3);  -- second source register
		dest_reg_addr := instruction_register(2 downto 0);  -- destination register
		branch_target := instruction_register(4 downto 0); 
		next_addr := '1';
    AC := accumulator_1;
    MQ := accumulator_2;
		
      case op_code is

        ----------------------------------------------------------------

        when "0000" => -- shift unit
          AC := R(to_integer(unsigned(src_reg1_addr))) ;
          case shift_code is
            when "000" => -- NSH
              AC := AC;

            when "001" => -- ZERO
              AC := (others => '0');
              ZF <= '1';

            when "010" => -- SHL
              CF <= AC(7);
              AC := std_logic_vector(shift_left(unsigned(AC), 1));
              

            when "011" => -- ROL
              AC := AC(6 downto 0) & AC(7);

            when "100" => -- RLC
              AC := AC(6 downto 0) & CF;
              SF <= AC(7);

            when "101" => -- SHR
              CF <= AC(0);
              AC := std_logic_vector(shift_right(unsigned(AC), 1));

            when "110" => -- ROR
              AC := AC(0) & AC(7 downto 1);

            when "111" => -- RRC
              AC := CF & AC(7 downto 1);

            when others =>
              null;
          end case;
			 if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
			 SF <= AC(7);
          destnation_register <= AC;
			 R(to_integer(unsigned(dest_reg_addr))) <= AC;
       accumulator_1 <= AC;
       accumulator_2 <= MQ;
        ----------------------------------------------------------------
        when "0001" => -- ALU operations

          AC := R(to_integer(unsigned(src_reg1_addr))) ;
          MQ := R(to_integer(unsigned(src_reg2_addr))) ;
          case instruction_register(11 downto 9) is
            when "000" => -- AC + MQ
              temp_result := std_logic_vector(('0' & unsigned(AC)) + ('0' & unsigned(MQ)));
              AC := temp_result(7 downto 0);
              CF <= temp_result(8);
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "001" => -- AC - MQ
              temp_result := std_logic_vector(('0' & unsigned(AC)) - ('0' & unsigned(MQ)));
              AC := temp_result(7 downto 0);
              CF <= temp_result(8);
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "010" => -- AC * MQ
              temp_mul := std_logic_vector(unsigned(AC) * unsigned(MQ));
              AC := temp_mul(7 downto 0);
              CF <= '0';
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "011" => -- AC / MQ
              if MQ /= "00000000" then
                AC := std_logic_vector(unsigned(AC) / unsigned(MQ));
              else
                AC := (others => '0');
              end if;
              CF <= '0';
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "100" => -- AND
              AC := AC and MQ;
              CF <= '0';
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "101" => -- OR
              AC := AC or MQ;
              CF <= '0';
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "110" => -- XOR
              AC := AC xor MQ;
              CF <= '0';
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "111" => -- NOT
              AC := not AC;
              CF <= '0';
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);
              MQ := x"00";
            when others =>
              null;
          end case;
          destnation_register <= AC;
			 R(to_integer(unsigned(dest_reg_addr))) <= AC;
        accumulator_1 <= AC;
        accumulator_2 <= MQ;
        ----------------------------------------------------------------
        -- Other opcodes (Store, Toggle, Increment/Decrement, etc.)
        when "0010" => -- Store to memory M[addr] ← $rs
          store_addr := instruction_register(2 downto 0);
          R( to_integer( unsigned(store_addr) )) <= AC;

        when "0011" => -- Load From Memory $rs ← M[addr] 
          store_addr := instruction_register(2 downto 0);
          accumulator_1 <= R( to_integer( unsigned(src_reg1_addr) ));
          accumulator_2 <= R( to_integer( unsigned(src_reg2_addr) ));

        when "0100" =>
          AC := not AC;
          CF <= '0';
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "0101" =>
          MQ := not MQ;
          CF <= '0';
          if MQ = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= MQ(7);
          destnation_register <= MQ;

        when "0110" => -- Branch if Lower than
          AC := not MQ;
          CF <= '0';
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "0111" => -- Mirror AC
          AC := AC(0) & AC(1) & AC(2) & AC(3) & AC(4) & AC(5) & AC(6) & AC(7);
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "1000" => -- Mirror MQ
          MQ := MQ(0) & MQ(1) & MQ(2) & MQ(3) & MQ(4) & MQ(5) & MQ(6) & MQ(7);
          CF <= '0';
          if MQ = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= MQ(7);
          destnation_register <= MQ;

        when "1001" =>
          if(accumulator_1 < accumulator_2) then
            pc_register := branch_target;
            next_addr := '0';
          end if;

        when "1010" => -- Branch LAD
          pc_register := branch_target;
          next_addr := '0';

        when "1011" => -- Branch LS
          if(SF = '1') then
            pc_register := branch_target;
            next_addr := '0';
          end if;

        when "1100" => -- Branch LC
          if(CF = '1') then
            pc_register := branch_target;
            next_addr := '0';
          end if;

        when "1101" => -- Branch LZ
          if(ZF = '1') then
            pc_register := branch_target;
            next_addr := '0';
          end if;

        when "1110" =>
          if(accumulator_1 = accumulator_2) then -- Branch if equal
            pc_register := branch_target;
            next_addr := '0';
          end if;
        when "1111" => -- Branch if greater than
						if(accumulator_1 > accumulator_2) then
							pc_register := branch_target;
							next_addr := '0';
						end if;
        when others =>
          null;

      end case; 
	   	
      if next_addr /= '0' then
        if unsigned(pc_register) = pc_size then
          pc_register := "00000";
        else
          pc_register := std_logic_vector(unsigned(pc_register) + 1);
        end if;
      end if;
		  pc_signal <= pc_register;
		-- destnation_register <= "000" & pc_register ; -- debug info displaying pc instead of output 
    end if;  
	 

  end process;
  
  process(kit_clk)
  
  variable num_int : integer range 0 to 99;
  variable tens : integer range 0 to 9;
  variable ones : integer range 0 to 9;
  
  begin
	if not(rising_edge(kit_clk)) then
	  num_int := to_integer( unsigned(destnation_register) );
	  tens := num_int / 10;    -- Get tens digit
	  ones := num_int mod 10;  -- Get ones digit
	  
	  tens_digit <= std_logic_vector(to_unsigned(tens, 4));
	  ones_digit <= std_logic_vector(to_unsigned(ones, 4));
	end if; 
  end process;
  -- Process 3: Clock divider for multiplexing (~50kHz refresh rate)
  process(kit_clk)
  begin
	  if not(rising_edge(kit_clk)) then
			refresh_counter <= refresh_counter + 1;
	  end if;
  end process;
 
  -- Use a MSB in counter for switching of 7 segments
  mux_sel <= refresh_counter (16);  -- ~381Hz refresh per digit (50MHz/2^17)

  -- Process 4: Multiplex between tens and ones digits
  process(mux_sel, tens_digit, ones_digit)
  begin
        if mux_sel = '0' then
            bcd_digit <= tens_digit;    -- Display tens digit
            anode <= "01";              -- Enable first display, disable second
        else
            bcd_digit <= ones_digit;    -- Display ones digit
            anode <= "10";              -- Enable second display, disable first
        end if;
  end process;
    
  -- Process 5: 7-segment decoder (for COMMON ANODE display)
  process(bcd_digit)
  begin
		case bcd_digit is
			  when "0000" => seven_segments <= "1000000"; -- 0
			  when "0001" => seven_segments <= "1111001"; -- 1
			  when "0010" => seven_segments <= "0100100"; -- 2
			  when "0011" => seven_segments <= "0110000"; -- 3
			  when "0100" => seven_segments <= "0011001"; -- 4
			  when "0101" => seven_segments <= "0010010"; -- 5
			  when "0110" => seven_segments <= "0000010"; -- 6
			  when "0111" => seven_segments <= "1111000"; -- 7
			  when "1000" => seven_segments <= "0000000"; -- 8
			  when "1001" => seven_segments <= "0010000"; -- 9

			  when others => seven_segments <= "1111111"; -- null
		end case;
  end process;

	 
end behavioral;