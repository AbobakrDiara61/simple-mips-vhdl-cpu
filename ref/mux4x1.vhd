library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
entity mux4x1 is 
port( x: in std_logic_vector(3 downto 0);
	  s: in std_logic_vector(1 downto 0);
	  f:out std_logic
);
end mux4x1;
architecture behaviour of mux4x1 is 
begin
f<=x(0) when s='00' else
f<=x(1) when s='01' else
f<=x(2) when s='10' else
f<=x(3) when s='11' else
'z';
end behaviour;
