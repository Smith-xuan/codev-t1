from cocotb.triggers import Timer

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

# Reset the DUT (design under test)
async def reset_dut(reset_n, duration_ns=10):
    reset_n.value = 0
    await Timer(duration_ns, units="ns")
    reset_n.value = 1
    await Timer(duration_ns, units='ns')
    reset_n._log.debug("Reset complete")

class FIFO:
    def __init__(self, stages):
        self.stages = stages
        self.queue = [0] * stages 

    def write(self, value):
        removed_value = self.queue[0]
        for i in range(self.stages - 1):
            self.queue[i] = self.queue[i + 1]
        self.queue[self.stages - 1] = value
        return removed_value

    def reset(self):
        self.queue = [0] * self.stages
    def to_list(self):
        return [self._convert_to_readable(val) for val in self.queue]

    def _convert_to_readable(self, value):
        try:
            return int(value)
        except (ValueError, TypeError):
            return str(value)
    def __str__(self):
        return f"FIFO: {self.to_list()}"