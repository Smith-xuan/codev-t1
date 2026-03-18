import cocotb
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_password_generator(dut):

    WIDTH = int(dut.WIDTH.value)  
    print(f"Detected WIDTH: {WIDTH} (Password length)")


    cocotb.start_soon(clock_gen(dut))


    print(f"Applying reset")
    await reset_dut(dut, WIDTH)
    print(f"reset completed")


    for _ in range(5): 
        await RisingEdge(dut.clk) 
        await Timer(1, units="ns")  

        password = extract_password(dut.password.value.integer, WIDTH)
        print(f"Generated Password: {password}")

     
        assert validate_password(password), f"Password validation failed: {password}"

    await Timer(10, units="ns")


async def reset_dut(dut, width):

    dut.reset.value = 1  
    await Timer(10, units="ns") 

  
    password = extract_password(dut.password.value.integer, width)
    print(f"Password during reset: {'0' * width}")  
    assert dut.password.value == 0, f"Password was not cleared during reset, got: {password}"

    dut.reset.value = 0 
    await Timer(10, units="ns") 


def extract_password(packed_password, width):

    password = ""
    for i in range(width):
        char_code = (packed_password >> (i * 8)) & 0xFF  
        password = chr(char_code) + password
    return password


def validate_password(password):

    has_lowercase = any('a' <= c <= 'z' for c in password)
    has_uppercase = any('A' <= c <= 'Z' for c in password)
    has_special = any(33 <= ord(c) <= 46 for c in password)
    has_numeric = any('0' <= c <= '9' for c in password)

    return has_lowercase and has_uppercase and has_special and has_numeric


async def clock_gen(dut):

    while True:
        dut.clk.value = 0
        await Timer(5, units="ns")  
        dut.clk.value = 1
        await Timer(5, units="ns") 
