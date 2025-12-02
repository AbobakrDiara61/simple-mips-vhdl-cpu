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

  -- computer system registers
  type Registers is array (0 to 7) of std_logic_vector(7 downto 0);
  signal R : Registers := (others => (others => '0'));

  -- Define ROM
  type ROM_Type is array (0 to 15) of std_logic_vector(15 downto 0);
  signal ROM : ROM_Type := (
    0  => "0000000000000010", -- Shift SHL
    1  => "0000000000000011", -- Shift ROL
    2  => "0001000000000000", -- ALU AC + MQ
    3  => "0001000100000000", -- ALU AC - MQ
    4  => "0001001000000000", -- ALU AC * MQ
    5  => "0001001100000000", -- ALU AC / MQ
    6  => "0001010000000000", -- ALU AC AND MQ
    7  => "0001010100000000", -- ALU AC OR MQ
    8  => "0001011000000000", -- ALU AC XOR MQ
    9  => "0001011100000000", -- ALU NOT AC
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
      shift_code <= instruction_register(2 downto 0);

      case op_code is

        ----------------------------------------------------------------
        when "0000" => -- shift unit
          case shift_code is
            when "000" => -- NSH
              AC <= AC;
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "001" => -- ZERO
              AC <= (others => '0');
              ZF <= '1';
              SF <= '0';

            when "010" => -- SHL
              CF <= AC(7);
              AC <= std_logic_vector(shift_left(unsigned(AC), 1));
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "011" => -- ROL
              AC <= AC(6 downto 0) & AC(7);
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "100" => -- RLC
              AC <= AC(6 downto 0) & CF;
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "101" => -- SHR
              CF <= AC(0);
              AC <= std_logic_vector(shift_right(unsigned(AC), 1));
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "110" => -- ROR
              AC <= AC(0) & AC(7 downto 1);
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when "111" => -- RRC
              AC <= CF & AC(7 downto 1);
              if AC = "00000000" then ZF <= '1'; else ZF <= '0'; end if;
              SF <= AC(7);

            when others =>
              null;
          end case;
			 
          destnation_register <= AC;

        ----------------------------------------------------------------
        when "0001" => -- ALU operations
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
          AC <= (others => '0');
          MQ <= (others => '0');
          ZF <= '1';
          SF <= '0';
          CF <= '0';
          destnation_register <= AC;

        when others =>
          null;

      end case;  
    end if;  
  end process;

end behavioral;