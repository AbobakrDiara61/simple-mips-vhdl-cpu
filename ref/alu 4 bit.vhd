library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity alu is 
port( a, b: in std_logic_vector(3 downto 0);
      s: in std_logic_vector(2 downto 0);
      y: out std_logic_vector(3 downto 0)
);
end alu;
architecture behavor of alu is 
signal y_unsign: std_logic_vector(3 downto 0);
signal y_signed: signed(3 downto 0);
signal a_signed,b_signed: signed(3 downto 0);
begin
a_signed<=signed(a);
b_signed<=signed(b);
with s(1 downto 0)select
y_signed<= a_signed + 1 when"00",
		   a_signed + b_signed when"01",
		   a_signed - b_signed when"10",
		   a_signed - 1 when others;
with s(1 downto 0)select
y_unsign<= a and b when "00",
           a or b when "01",
		   a xor b when "10",
		   not a when others;
with s(2)select
y<= std_logic_vector(y_signed) when '0',
   y_unsign when others;
end behavor;

	