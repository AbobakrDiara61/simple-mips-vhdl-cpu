library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
entity ha is
port( a,b:in std_logic;
	  s,co:out std_logic
);
end ha;
architecture behaviour of ha is
begin
s<= a xor b;
co<= a and b;
end behaviour;
