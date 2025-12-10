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
  -- Seven Segment signals
  signal refresh_counter : unsigned(16 downto 0) := (others => '0');
  signal mux_sel         : STD_LOGIC := '0';
  signal bcd_digit       : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
  signal tens_digit      : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
  signal ones_digit      : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
  
  -- computer system registers
  type Registers is array (0 to 7) of std_logic_vector(7 downto 0);
  signal R : Registers := (
    0 => "00000001",
    1 => "00000010",
    2 => "00000100",
    3 => "00000000",
    4 => "00000101",
    5 => "00100111",
    6 => "01000000",
    7 => "01000000"
  );

  -- Define ROM
  type ROM_Type is array (0 to 31) of std_logic_vector(15 downto 0);
  signal ROM : ROM_Type := (
    -- Shift operations (opcode 0000)
	 0  => "0001000000010010", -- op=0001(func=000) AC=R0 + MQ=R1 -> R2
	 1  => "0000010000100010", -- op=0000(func=010) SHL R2 -> R2
    2  => "1111000001110001", -- op=1111(cond=1) Branch if AC > MQ to addr 0111
    3  => "0000010100000000", -- op=0000(func=010) SHL R4 -> R0
    4  => "0000011000000000", -- ROL  R0 <- R0
    5  => "0000000100000000", -- ZERO (clear AC)
    
    -- ALU operations (opcode 0001)
    6  => "0000001000000000", -- SHR (shift right)
    7  => "0001001000011000", -- AC - MQ (R1 - R1 -> R0)
    8  => "0001010000101000", -- AC * MQ (R2 * R2 -> R0)
    9  => "0001011000111000", -- AC / MQ (R3 / R3 -> R0)
    10 => "0001100001001000", -- AC AND MQ (R4 AND R4 -> R0)
    11 => "0001101001011000", -- AC OR MQ (R5 OR R5 -> R0)
    12 => "0001110001101000", -- AC XOR MQ (R6 XOR R6 -> R0)
    13 => "0001111001111000", -- NOT AC (R7 -> R0)
    
    -- Store and double operations
    14 => "0010000000000000", -- Store AC in R0, double AC
    15 => "0011000000000000", -- Double MQ
    
    -- Toggle operations
    16 => "0100000000000000", -- Toggle AC
    17 => "0101000000000000", -- Toggle MQ
    
    -- Transfer operations
    18 => "0110000000000000", -- AC = NOT MQ
    19 => "0111000000000000", -- Mirror AC bits
    20 => "1000000000000000", -- Mirror MQ bits
    
    -- Store and double MQ
    21 => "1001000000000000", -- Store MQ in R1, double MQ
    
    -- Increment/Decrement operations
    22 => "1010000000000000", -- Increment AC
    23 => "1011000000000000", -- Decrement AC
    24 => "1100000000000000", -- Decrement MQ
    
    -- Clear operations
    25 => "1101000000000000", -- Clear AC
    
    -- Branch operations (1110)
    26 => "1110000000000000", -- Branch LC (Carry)
    27 => "1110000000000001", -- Branch LZ (Zero)
    
    -- Compare and branch operations (1111)
    28 => "1111000000000000", -- Branch if equal (AC == MQ)
    29 => "1111000000000001", -- Branch if greater than (AC > MQ)
    
    -- Additional test instructions
    30 => "0000011100000000", -- RLC (rotate left through carry)
    31 => "0000011100000000"  -- RLC (another one for testing)
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
  variable branch_cond: std_logic := '0';
  variable next_addr: std_logic := '1';
  variable op_code: std_logic_vector(3 downto 0);
  variable AC : std_logic_vector(7 downto 0) := x"00";
  variable MQ : std_logic_vector(7 downto 0) := x"00";
  variable shift_code: std_logic_vector(2 downto 0);
  variable memory_rw: std_logic := '0';
  
  begin
    if not(i_reset) = '1' then
      -- reset
      AC := x"00";
      MQ := x"00";
      pc_signal <= (others => '0');
      ZF <= '0';
      SF <= '0';
      CF <= '0';
		destnation_register <= x"00";	
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
		branch_target := instruction_register(5 downto 1); 
		branch_cond  := instruction_register(0);
		next_addr := '1';
		AC := R(to_integer(unsigned(src_reg1_addr))) ;
		MQ := R(to_integer(unsigned(src_reg2_addr))) ;
		
      case op_code is

        ----------------------------------------------------------------

        when "0000" => -- shift unit

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
        ----------------------------------------------------------------
        when "0001" => -- ALU operations

			 
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

            when others =>
              null;
          end case;
          destnation_register <= AC;
			 R(to_integer(unsigned(dest_reg_addr))) <= AC;
        ----------------------------------------------------------------
        -- Other opcodes (Store, Toggle, Increment/Decrement, etc.)
        when "0010" =>
          R(0) <= AC;
          AC := std_logic_vector(unsigned(AC) + unsigned(AC));
          CF <= '0';
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "0011" =>
          MQ := std_logic_vector(unsigned(MQ) + unsigned(MQ));
          CF <= '0';
          if MQ = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= MQ(7);
          destnation_register <= MQ;

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

        when "0110" =>
          AC := not MQ;
          CF <= '0';
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "0111" =>
          AC := AC(0) & AC(1) & AC(2) & AC(3) & AC(4) & AC(5) & AC(6) & AC(7);
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "1000" =>
          MQ := MQ(0) & MQ(1) & MQ(2) & MQ(3) & MQ(4) & MQ(5) & MQ(6) & MQ(7);
          CF <= '0';
          if MQ = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= MQ(7);
          destnation_register <= MQ;

        when "1001" =>
          R(1) <= MQ;
          MQ := std_logic_vector(unsigned(MQ) + unsigned(MQ));
          CF <= '0';
          if MQ = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= MQ(7);
          destnation_register <= MQ;

        when "1010" =>
          AC := std_logic_vector(unsigned(AC) + 1);
          CF <= '0';
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "1011" =>
          AC := std_logic_vector(unsigned(AC) - 1);
          CF <= '0';
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "1100" =>
          MQ := std_logic_vector(unsigned(MQ) - 1);
          CF <= '0';
          if MQ = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= MQ(7);
          destnation_register <= MQ;

        when "1101" =>
          AC := (others => '0');
          ZF <= '1';
          SF <= '0';
          CF <= '0';
          destnation_register <= AC;

        when "1110" =>
		  
				case branch_cond is
					when '0' => -- Branch LC
						if(CF = '1') then
							pc_register := branch_target;
							next_addr := '0';
						end if;
						
					when '1' => -- Branch LZ
						if(ZF = '1') then
							pc_register := branch_target;
							next_addr := '0';
						end if;
						
					when others =>
					  null;
				end case;
				
				
        when "1111" =>
		  
				case branch_cond is
					when '0' => -- Branch if equal
						if(AC = MQ) then
							pc_register := branch_target;
							next_addr := '0';
						end if;
						
					when '1' => -- Branch if greater than
						if(AC > MQ) then
							pc_register := branch_target;
							next_addr := '0';
						end if;

					when others =>
					  null;
				end case;

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