library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.ALL;

entity kerna is
 port(
  i_reset: in std_logic;
  i_clock: in std_logic;
  i_loadPC: in std_logic;
  i_incPC: in std_logic;
  i_pcLoadValue: in std_logic_vector(3 downto 0);

  destnation_register : out std_logic_vector(7 downto 0) := x"00"
 );
end kerna;

architecture behavioral of kerna is 
  -- signal section
  signal pc_register : std_logic_vector(3 downto 0);
  signal instruction_register : std_logic_vector(15 downto 0);
  signal op_code: std_logic_vector(3 downto 0);
  signal shift_code: std_logic_vector(2 downto 0); -- 3 bits only
  signal AC : std_logic_vector(7 downto 0) := x"00";
  signal MQ : std_logic_vector(7 downto 0) := x"00";
  signal SF, ZF, CF: std_logic := '0';
  signal temp_result: std_logic_vector(8 downto 0);
  signal temp_mul: std_logic_vector(15 downto 0);
  signal src_reg1_addr: std_logic_vector(2 downto 0);
  signal src_reg2_addr: std_logic_vector(2 downto 0);
  signal dest_reg_addr: std_logic_vector(2 downto 0);
  signal branch_target: std_logic_vector(3 downto 0);
  signal branch_cond: std_logic_vector(1 downto 0);
  
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
    7 => "00010000"
  );

  -- Define ROM
  type ROM_Type is array (0 to 15) of std_logic_vector(15 downto 0);
  signal ROM : ROM_Type := (
    0  => "0000100000000000", -- Shift SHL
    1  => "0000110000000000", -- Shift ROL
    2  => "0001000000000000", -- ALU AC + MQ
    3  => "0001001000000000", -- ALU AC - MQ
    4  => "0001010000000000", -- ALU AC * MQ
    5  => "0001011000000000", -- ALU AC / MQ
    6  => "0001100000000000", -- ALU AC AND MQ
    7  => "0001101000000000", -- ALU AC OR MQ
    8  => "0001110000000000", -- ALU AC XOR MQ
    9  => "0001111000000000", -- ALU NOT AC
    10 => "0010000000000000", -- Store AC in R0, double AC
    11 => "0011000000000000", -- Double MQ
    12 => "0100000000000000", -- Toggle AC
    13 => "0101000000000000", -- Toggle MQ
    14 => "0110000000000000", -- AC = NOT MQ
    15 => "0111000000000000"  -- Mirror AC bits
  );

begin 
  process (i_reset, i_clock)
  begin
    if i_reset = '1' then
      -- reset
      AC <= x"00";
      MQ <= x"00";
      pc_register <= (others => '0');
      ZF <= '0';
      SF <= '0';
      CF <= '0';

    elsif rising_edge(i_clock) then

      -- Update PC
      if i_loadPC = '1' then
        pc_register <= i_pcLoadValue;
      elsif i_incPC = '1' then
        if unsigned(pc_register) = 15 then
          pc_register <= "0000";
        else
          pc_register <= std_logic_vector(unsigned(pc_register) + 1);
        end if;
      end if;

      -- Fetch instruction
      instruction_register <= ROM(to_integer(unsigned(pc_register)));

      -- Extract info from IR 
      op_code <= instruction_register(15 downto 12);
      shift_code <= instruction_register(11 downto 9);
		src_reg1_addr <= instruction_register(8 downto 6);  -- first source register
		src_reg2_addr <= instruction_register(5 downto 3);  -- second source register
		dest_reg_addr <= instruction_register(2 downto 0);  -- destination register
		branch_target <= instruction_register(5 downto 2); 
		branch_cond  <= instruction_register(1 downto 0);
      case op_code is

        ----------------------------------------------------------------
        when "0000" => -- shift unit
          case shift_code is
            when "000" => -- NSH
              AC <= AC;

            when "001" => -- ZERO
              AC <= (others => '0');
              ZF <= '1';

            when "010" => -- SHL
              CF <= AC(7);
              AC <= std_logic_vector(shift_left(unsigned(AC), 1));              

            when "011" => -- ROL
              AC <= AC(6 downto 0) & AC(7);

            when "100" => -- RLC
              AC <= AC(6 downto 0) & CF;
              SF <= AC(7);

            when "101" => -- SHR
              CF <= AC(0);
              AC <= std_logic_vector(shift_right(unsigned(AC), 1));

            when "110" => -- ROR
              AC <= AC(0) & AC(7 downto 1);

            when "111" => -- RRC
              AC <= CF & AC(7 downto 1);

            when others =>
              null;
          end case;
			 if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
			 SF <= AC(7);
          destnation_register <= AC;
			 R(to_integer(unsigned(dest_reg_addr))) <= AC;
        ----------------------------------------------------------------
        when "0001" => -- ALU operations
		    AC <= R(to_integer(unsigned(src_reg1_addr))) ;
			 MQ <= R(to_integer(unsigned(src_reg2_addr))) ;
			 
          case instruction_register(11 downto 9) is
            when "000" => -- AC + MQ
              temp_result <= std_logic_vector(('0' & unsigned(AC)) + ('0' & unsigned(MQ)));
              AC <= temp_result(7 downto 0);
              CF <= temp_result(8);
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "001" => -- AC - MQ
              temp_result <= std_logic_vector(('0' & unsigned(AC)) - ('0' & unsigned(MQ)));
              AC <= temp_result(7 downto 0);
              CF <= temp_result(8);
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "010" => -- AC * MQ
              temp_mul <= std_logic_vector(unsigned(AC) * unsigned(MQ));
              AC <= temp_mul(7 downto 0);
              CF <= '0';
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "011" => -- AC / MQ
              if MQ /= "00000000" then
                AC <= std_logic_vector(unsigned(AC) / unsigned(MQ));
              else
                AC <= (others => '0');
              end if;
              CF <= '0';
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "100" => -- AND
              AC <= AC and MQ;
              CF <= '0';
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "101" => -- OR
              AC <= AC or MQ;
              CF <= '0';
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "110" => -- XOR
              AC <= AC xor MQ;
              CF <= '0';
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "111" => -- NOT
              AC <= not AC;
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
          AC <= std_logic_vector(unsigned(AC) + unsigned(AC));
          CF <= '0';
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "0011" =>
          MQ <= std_logic_vector(unsigned(MQ) + unsigned(MQ));
          CF <= '0';
          if MQ = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= MQ(7);
          destnation_register <= MQ;

        when "0100" =>
          AC <= not AC;
          CF <= '0';
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "0101" =>
          MQ <= not MQ;
          CF <= '0';
          if MQ = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= MQ(7);
          destnation_register <= MQ;

        when "0110" =>
          AC <= not MQ;
          CF <= '0';
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "0111" =>
          AC <= AC(0) & AC(1) & AC(2) & AC(3) & AC(4) & AC(5) & AC(6) & AC(7);
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "1000" =>
          MQ <= MQ(0) & MQ(1) & MQ(2) & MQ(3) & MQ(4) & MQ(5) & MQ(6) & MQ(7);
          CF <= '0';
          if MQ = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= MQ(7);
          destnation_register <= MQ;

        when "1001" =>
          R(1) <= MQ;
          MQ <= std_logic_vector(unsigned(MQ) + unsigned(MQ));
          CF <= '0';
          if MQ = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= MQ(7);
          destnation_register <= MQ;

        when "1010" =>
          AC <= std_logic_vector(unsigned(AC) + 1);
          CF <= '0';
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "1011" =>
          AC <= std_logic_vector(unsigned(AC) - 1);
          CF <= '0';
          if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= AC(7);
          destnation_register <= AC;

        when "1100" =>
          MQ <= std_logic_vector(unsigned(MQ) - 1);
          CF <= '0';
          if MQ = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
          SF <= MQ(7);
          destnation_register <= MQ;

        when "1101" =>
          AC <= (others => '0');
          ZF <= '1';
          SF <= '0';
          CF <= '0';
          destnation_register <= AC;

        when "1110" =>
          MQ <= (others => '0');
          ZF <= '1';
          SF <= '0';
          CF <= '0';
          destnation_register <= MQ;

        when "1111" =>
			 branch_target <= instruction_register(5 downto 2);
			 branch_cond  <= instruction_register(1 downto 0);

				case branch_cond is
					when "00" => -- Branch if equal
						if(AC = MQ) then
							pc_register <= branch_target;
						end if;
						
					when "01" => -- Branch if greater than
						if(AC > MQ) then
							pc_register <= branch_target;
						end if;
						
					when "10" => -- Branch LC
						if(CF = '1') then
							pc_register <= branch_target;
						end if;
						
					when "11" => -- Branch LZ
						if(ZF = '1') then
							pc_register <= branch_target;
						end if;
						
					when others =>
					  null;
				end case;

        when others =>
          null;

      end case; 
	   	
      if op_code /= "1111" then
        if unsigned(pc_register) = 15 then
          pc_register <= "0000";
        else
          pc_register <= std_logic_vector(unsigned(pc_register) + 1);
        end if;
      end if;
		
    end if;  
  end process;

end behavioral;