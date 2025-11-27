library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mip_microprocessor is
	port(
		clk,reset : in std_logic;
		zero_flag,carry_flag: out std_logic;
		pc: out std_logic_vector(3 downto 0);
		destnation_register : out std_logic_vector( 7 downto 0) := x"00"
	);
end entity;

architecture mips_behav of mip_microprocessor is
	type Registers is array (0 to 7) of std_logic_vector(7 downto 0);
	signal R : Registers := (others => (others => '0'));
	
	type Instructions_rom is array (0 to 15) of std_logic_vector(15 downto 0);
	constant MyRom : Instructions_rom :=(
		"0111011000000000", --R3=0
		"0111001000101000", --R1=40
		"0111010000000101", --R2=5
		"0011001001000101", --R1=R1-5
		"0010101101000001", --R3=R3+1
		"1011001010000010", --if(R1>=R2) goto third instraction , else:
		"0111001111111111", --R1=-1
		x"0000",
		x"0000",
		x"0000",
		x"0000",
		x"0000",
		x"0000",
		x"0000",
		x"0000",
		x"0000"
	);
	signal pc_current: std_logic_vector(3 downto 0) :="0000";
        signal rd: std_logic_vector(7 downto 0) := x"00";
	signal alu_func: std_logic_vector (2 downto 0) := "000";
	signal instruction_register : std_logic_vector(15 downto 0) := x"0000";
	signal memory_rw, CF, ZF : std_logic := '0'; --flags
	
	
	begin
		process(clk)
		variable temp_result : std_logic_vector(15 downto 0);
		variable opcode : std_logic_vector(3 downto 0);
		variable instruction_register_v : std_logic_vector(15 downto 0);
		variable  alu_func_v,rs_num, rt_num, rd_num : std_logic_vector (2 downto 0) := "000";
		variable addr12 : std_logic_vector(11  downto 0);
		variable rs,rt: std_logic_vector(7 downto 0) := x"00";
		variable immediate6,addr6 : std_logic_vector(5 downto 0);
		variable immediate9,addr9 : std_logic_vector(8 downto 0);
		begin
			if reset = '1' then
				pc_current <= "0000";

			elsif (rising_edge(clk)) then
					
					instruction_register_v := MyRom(to_integer(unsigned(pc_current(3 downto 0)))); --fetching the instruction register into the variable named instruction register
					
					rs_num := instruction_register_v(11 downto 9);
					rt_num := instruction_register_v(8 downto 6);
					rd_num := instruction_register_v(5 downto 3);
					alu_func_v := instruction_register_v( 2 downto 0);
					immediate6 := instruction_register_v(5 downto 0);
					immediate9 := instruction_register_v(8 downto 0);
					addr9 := instruction_register_v(8 downto 0);
					addr6:= instruction_register_v(5 downto 0);
					addr12 := instruction_register_v(11 downto 0);
					opcode := instruction_register_v(15 downto 12);
					
					rs := R(to_integer(unsigned(rs_num))); -- getting the rs and rt as integer numbers
					rt := R(to_integer(unsigned(rt_num)));

					alu_func <= alu_func_v; -- assigning the alu function
					instruction_register <= instruction_register_v; --assigning the variable to the real signal
				pc_current <= std_logic_vector(unsigned(pc_current) + 1 ); --updating the pc
				case opcode is
					when x"1" => -- "0001" case
						case alu_func_v is	
							when "000" =>
								temp_result(8 downto 0) := std_logic_vector(('0' & unsigned(rs)) + ('0' & unsigned(rt)));
								CF <= temp_result(8); --carry flag (8th bit for carry bit)
							when "001" =>
								temp_result(8 downto 0) := std_logic_vector(('0' & unsigned(rs)) - ('0' & unsigned(rt)));
								CF <= temp_result(8); --carry flag (8th bit for carry bit)
							when "010" =>
								temp_result := std_logic_vector(unsigned(rs) * unsigned (rt));
							when "011" =>
								temp_result(7 downto 0) := std_logic_vector( unsigned( rs) / unsigned(rt));
								temp_result(15 downto 8) := x"00";
							when "100" =>
								temp_result(7 downto 0) :=(rs and rt);
							when "101" =>
								temp_result(7 downto 0) :=  (rs or rt);
							when "110" =>
								temp_result(7 downto 0) :=   (rs xor rt);
							when "111" =>
								temp_result(7 downto 0) :=  (not rs);
							when others =>
								
						end case;
						destnation_register <= temp_result(7 downto 0);
						if temp_result(7 downto 0) = x"00" then 
							ZF <= '1'; -- none of the operations was done so flag = 1
						else 
							Zf <= '0';
						end if;
						R(to_integer(unsigned(rd_num))) <= temp_result(7 downto 0);
						
					when x"2" =>
						temp_result (7 downto 0) := std_logic_vector(signed(rs) + signed(immediate6));
						rt := temp_result (7 downto 0);
						destnation_register <= temp_result (7 downto 0); --sending the value to destination register
						R(to_integer(unsigned(rt_num))) <= temp_result (7 downto 0); -- storing the result in the register mentioned in table
					when x"3" =>
						temp_result (7 downto 0) := std_logic_vector(signed(rs) - signed(immediate6));
						rt := temp_result (7 downto 0);
						destnation_register <= temp_result (7 downto 0);
						R(to_integer(unsigned(rt_num))) <= temp_result (7 downto 0);
					when x"4" =>
						temp_result(7 downto 0) := rs and ("00" & immediate6);
						destnation_register <= temp_result(7 downto 0);
						R(to_integer(unsigned(rt_num))) <= temp_result(7 downto 0);
					when x"5" =>
						temp_result(7 downto 0) := rs or ("00" & immediate6);
						destnation_register <= temp_result(7 downto 0);
						R(to_integer(unsigned(rt_num))) <= temp_result(7 downto 0);
					when x"6" =>
						temp_result(7 downto 0) := rs xor ("00" & immediate6);
						destnation_register <= temp_result(7 downto 0);
						R(to_integer(unsigned(rt_num))) <= temp_result(7 downto 0);
						
					when x"7" =>
						temp_result(7 downto 0) := immediate9(7 downto 0);
						destnation_register <= temp_result(7 downto 0);
						R(to_integer(unsigned(rs_num))) <= temp_result(7 downto 0);
						
					when x"8" =>
						memory_rw <= '0';
					when x"9" =>
						memory_rw <= '1';
					when x"A" =>   --beq
						if rs = rt then
							pc_current <= addr6(3 downto 0);
						end if;
					when x"B" =>
						if rs >= rt then
							pc_current <= addr6(3 downto 0);
						end if;
					when x"C" =>
						if rs < rt then
							pc_current <= addr6(3 downto 0);
						end if;
					when x"D" =>
						if CF = '1' then
							pc_current <= addr12(3 downto 0);
						end if;
					when x"E" =>
						if ZF = '1' then
							pc_current <= addr12(3 downto 0);
						end if;
					when x"F" =>
						pc_current <= addr12(3 downto 0);
					when others =>
						destnation_register <= x"00";
						zf <= '1';
				end case;
			end if;

			
		end process;
pc<=pc_current;
zero_flag<=ZF;
carry_flag<=CF;
end architecture;
