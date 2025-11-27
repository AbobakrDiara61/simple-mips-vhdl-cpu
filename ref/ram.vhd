library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity ram is
	generic(n : integer := 8);
    port (
        address  : in  std_logic_vector(2 downto 0);
        input  : in  std_logic_vector(n-1 downto 0);
        output : out std_logic_vector(n-1 downto 0);
        ce,wr,re : in  std_logic
    );
end ram;
architecture behav of RAM is
    type ram_arr is array (0 to n-1) of std_logic_vector(n-1 downto 0);
    signal memory : ram_arr;
begin
    process (address, input, ce, wr,re)
    begin
        if ce = '1' and wr='1' and re='0' then
               memory(to_integer(unsigned(address))) <= input;
        elsif ce = '1' and re='1' and wr='0' then
               output <= memory(to_integer(unsigned(address)));
        else
            output <= (others => '0');
        end if;
    end process;
end behav;