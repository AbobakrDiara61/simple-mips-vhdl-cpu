library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity seg is
    Generic (
        Bit_Size : integer := 4
    );
    Port(
        BCD    : in STD_LOGIC_VECTOR ( Bit_Size-1 downto 0 );
        seven_segments   : out STD_LOGIC_VECTOR ( 6 downto 0 )
    );
end seg;

architecture Behavioral of seg is
    signal temp_result : STD_LOGIC_VECTOR ( Bit_Size downto 0 );
	 
begin
	process(BCD)
	begin
		 temp_result <= BCD;

		 case temp_result is

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

end Behavioral;