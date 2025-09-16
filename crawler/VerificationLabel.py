from enum import Enum


class VerificationLabel(Enum):
    UNDEFINED = 0
    VALID = 1
    MISDESIGNED = 2
    EXPLOITABLE = 3
    ERROR = 4
    FUNCTIONAL_BROKEN = 5
    OBJECT_BROKEN = 6
    PROPERTY_BROKEN = 7
    OTHER_MYSQL_ERROR = 8

    def __lt__(self, other):
        if self.__class__ is other.__class__:
            return self.value < other.value
        return NotImplemented