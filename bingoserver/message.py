from asyncio import Queue, timeout, TimeoutError, QueueFull

from models.events import EventModel

QUEUE_TIMEOUT = 20
QUEUE_MAXSIZE = 100


class MessageQueue:
    def __init__(self) -> None:
        self.queues: dict[int, Queue] = {}

    def create_if_not_exists(self, address: int):
        if address not in self.queues.keys():
            self.queues[address] = Queue(QUEUE_MAXSIZE)

    async def get(self, address: int) -> list[EventModel]:
        self.create_if_not_exists(address)
        events = []

        try:
            async with timeout(QUEUE_TIMEOUT):
                event = await self.queues[address].get()
                events.append(event)

                while event := self.queues[address].get_nowait():
                    events.append(event)

                return events
        except TimeoutError:
            return []

    def put(self, address: int, message: EventModel):
        self.create_if_not_exists(address)

        try:
            self.queues[address].put_nowait(message)
        except QueueFull:
            pass

    def broadcast(self, message: EventModel):
        for queue in self.queues.values():
            try:
                queue.put_nowait(message)
            except QueueFull:
                pass
