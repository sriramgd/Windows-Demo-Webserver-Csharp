namespace MyServer
{
    public class BadRequestException : System.ApplicationException
    {
        public BadRequestException() { }
        public BadRequestException(string message) { }
        public BadRequestException(string message, System.Exception inner) { }

        // Constructor needed for serialization 
        // when exception propagates from a remoting server to the client.
        protected BadRequestException(System.Runtime.Serialization.SerializationInfo info,
            System.Runtime.Serialization.StreamingContext context) { }
    }

    public class ForbiddenException : System.ApplicationException
    {
        public ForbiddenException() { }
        public ForbiddenException(string message) { }
        public ForbiddenException(string message, System.Exception inner) { }

        // Constructor needed for serialization 
        // when exception propagates from a remoting server to the client.
        protected ForbiddenException(System.Runtime.Serialization.SerializationInfo info,
            System.Runtime.Serialization.StreamingContext context) { }
    }

    public class HiddenException : System.ApplicationException
    {
        public HiddenException() { }
        public HiddenException(string message) { }
        public HiddenException(string message, System.Exception inner) { }

        // Constructor needed for serialization 
        // when exception propagates from a remoting server to the client.
        protected HiddenException(System.Runtime.Serialization.SerializationInfo info,
            System.Runtime.Serialization.StreamingContext context) { }
    }

    public class NotFoundException : System.ApplicationException
    {
        public NotFoundException() { }
        public NotFoundException(string message) { }
        public NotFoundException(string message, System.Exception inner) { }

        // Constructor needed for serialization 
        // when exception propagates from a remoting server to the client.
        protected NotFoundException(System.Runtime.Serialization.SerializationInfo info,
            System.Runtime.Serialization.StreamingContext context) { }
    }
}