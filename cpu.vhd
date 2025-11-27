library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.ALL;

entity cpu is
 port(
	i_reset: in std_logic;
	i_clock: in std_logic;
	i_loadPC: in std_logic;
	i_incPC: in std_logic;
	i_pcLoadValue: in std_logic_vector( 3 downto 0 );
	
	destnation_register : out std_logic_vector( 7 downto 0) := x"00"
 );
end cpu;

architecture behavioral of cpu is 
	-- signal section
	signal pc_register : std_logic_vector( 3 downto 0 );
	signal instruction_register : std_logic_vector( 15 downto 0 );
	signal op_code: std_logic_vector( 3 downto 0 );
	signal shift_code: std_logic_vector( 3 downto 0 );
	signal AC : std_logic_vector( 7 downto 0) := x"00";
	signal MQ : std_logic_vector( 7 downto 0) := x"00";
	signal carry: std_logic;
	-- computer system registers (like memory instead of making a ram 
	type Registers is array (0 to 7) of std_logic_vector(7 downto 0);
	signal R : Registers := (others => (others => '0'));
	
	
	
	-- here we put our rom as  
		-- we get the instructions from	
		-- we get the addr of which registers we will use too
	instruction_register <= ROM(to_integer(pc_current) );

	begin 
		process (i_reset, i_clock)
		variable Z_flag: std_logic;
		variable S_flag: std_logic;
		begin
			if i_reset = '1' then
				-- reset
				AC <= x"00";
				MQ <= x"00";
				pc_register <= (others => '0');
				
			elsif rising_edge(i_clock) then
				-- here we extract info from IR 
				op_code <= instruction_register(15 downto 12);
				
				shift_code <= instruction_register(2 downto 0);
				
				
				case op_code is
					when "0000" => -- shift unit here
						case shift_code is
							when "000" =>
								AC <= AC; -- NSH
							when "001" =>
								AC <= (others => '0'); -- ZERO
							when "010" =>
								carry <= AC(7);  -- Save MSB to carry
								AC <= std_logic_vector(shift_left(unsigned(AC), 1)); -- SHL
							when "011" =>
								AC <= AC(6 downto 0) & AC(7); -- ROL
							when "100" =>
								AC <= AC(6 downto 0) & carry; -- RLC
							when "101" =>
								carry <= AC(0);  -- Save LSB to carry
								AC <= std_logic_vector(shift_right(unsigned(AC), 1)); -- SHR
							when "110" =>
								AC <= AC(0) & AC(7 downto 1); -- ROR
							when "111" =>
								AC <= carry & AC(7 downto 1); -- RRC
							when others => NULL;
						end case;
						destnation_register <= AC; 
					when "0001" => --alu here
					when "0010" => 
					when "0011" => 
					when "0100" => 
					when "0101" => 
					when "0110" => 
					when "0111" => 
					when "1000" => 
					when "1001" => 
					when "1010" => 
					when "1011" => 
					when "1100" => 
					when "1101" => 
					when "1110" => 
					when "1111" => 
					when others =>
				end case;	
			end if;  
		end process;
		

end behavioral;
