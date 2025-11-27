library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity rom is
    Port ( address : in STD_LOGIC_VECTOR(3 downto 0);
           ce : in STD_LOGIC;
           re : in STD_LOGIC;
           data_out : out STD_LOGIC_VECTOR(15 downto 0)
         );
end rom;

architecture Behavioral of rom is
    type rom_type is array (0 to 15) of STD_LOGIC_VECTOR(15 downto 0);
    signal rom_data : rom_type := (
        "1000000000000000", 
        "1100000000000000", 
        "1110000000000000", 
        "1111000000000000", 
        "1111100000000000", 
        "1111110000000000", 
        "1111111000000000", 
        "1111111100000000", 
        "1111111110000000", 
        "1111111111000000", 
        "1111111111100000", 
        "1111111111110000", 
        "1111111111111000", 
        "1111111111111100", 
        "1111111111111110", 
        "1111111111111111" 
    );
begin
    process (ce, re, address)
    begin
        if ce = '1' and re = '1' then
            data_out <= rom_data(to_integer(unsigned(address)));
        else
            data_out <= (others => '0');
        end if;
    end process;
end Behavioral;