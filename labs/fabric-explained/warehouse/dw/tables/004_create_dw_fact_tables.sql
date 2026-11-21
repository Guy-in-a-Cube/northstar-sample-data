CREATE TABLE [dw].[FactBooking] (
    [BookingID]          BIGINT          NOT NULL,
    [BookingDateKey]     INT             NOT NULL,
    [CheckInDateKey]     INT             NOT NULL,
    [CheckOutDateKey]    INT             NOT NULL,
    [PropertyKey]        BIGINT          NOT NULL,
    [GuestKey]           BIGINT          NOT NULL,
    [ChannelKey]         BIGINT          NOT NULL,
    [ExperienceKey]      BIGINT          NULL,
    [NightsBooked]       INT             NOT NULL,
    [RoomsBooked]        INT             NOT NULL,
    [CancellationAmount] DECIMAL (18, 2) NOT NULL,
    [IsCancelled]        BIT             NOT NULL,
    [IsLoyaltyBooking]   BIT             NOT NULL,
    [SourceUpdatedAt]    DATETIME2 (3)   NULL
);


GO

ALTER TABLE [dw].[FactBooking]
    ADD CONSTRAINT [FK_FactBooking_BookingDate] FOREIGN KEY ([BookingDateKey]) REFERENCES [dw].[DimDate] ([DateKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactBooking]
    ADD CONSTRAINT [FK_FactBooking_Channel] FOREIGN KEY ([ChannelKey]) REFERENCES [dw].[DimChannel] ([ChannelKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactBooking]
    ADD CONSTRAINT [FK_FactBooking_CheckInDate] FOREIGN KEY ([CheckInDateKey]) REFERENCES [dw].[DimDate] ([DateKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactBooking]
    ADD CONSTRAINT [FK_FactBooking_CheckOutDate] FOREIGN KEY ([CheckOutDateKey]) REFERENCES [dw].[DimDate] ([DateKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactBooking]
    ADD CONSTRAINT [FK_FactBooking_Experience] FOREIGN KEY ([ExperienceKey]) REFERENCES [dw].[DimExperience] ([ExperienceKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactBooking]
    ADD CONSTRAINT [FK_FactBooking_Guest] FOREIGN KEY ([GuestKey]) REFERENCES [dw].[DimGuest] ([GuestKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactBooking]
    ADD CONSTRAINT [FK_FactBooking_Property] FOREIGN KEY ([PropertyKey]) REFERENCES [dw].[DimProperty] ([PropertyKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactBooking]
    ADD CONSTRAINT [PK_FactBooking] PRIMARY KEY NONCLUSTERED ([BookingID] ASC) NOT ENFORCED;


GO

CREATE TABLE [dw].[FactStayNight] (
    [StayNightID]       BIGINT          NOT NULL,
    [BookingID]         BIGINT          NOT NULL,
    [StayDateKey]       INT             NOT NULL,
    [PropertyKey]       BIGINT          NOT NULL,
    [NightNumber]       INT             NOT NULL,
    [RoomsOccupied]     INT             NOT NULL,
    [RoomRevenue]       DECIMAL (18, 2) NOT NULL,
    [ExperienceRevenue] DECIMAL (18, 2) NOT NULL,
    [OtherRevenue]      DECIMAL (18, 2) NOT NULL,
    [DiscountAmount]    DECIMAL (18, 2) NOT NULL,
    [SourceUpdatedAt]   DATETIME2 (3)   NULL,
    [GuestKey]          BIGINT          NULL,
    [ExperienceKey]     BIGINT          NULL
);


GO

ALTER TABLE [dw].[FactStayNight]
    ADD CONSTRAINT [FK_FactStayNight_Experience] FOREIGN KEY ([ExperienceKey]) REFERENCES [dw].[DimExperience] ([ExperienceKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactStayNight]
    ADD CONSTRAINT [FK_FactStayNight_Guest] FOREIGN KEY ([GuestKey]) REFERENCES [dw].[DimGuest] ([GuestKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactStayNight]
    ADD CONSTRAINT [FK_FactStayNight_Property] FOREIGN KEY ([PropertyKey]) REFERENCES [dw].[DimProperty] ([PropertyKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactStayNight]
    ADD CONSTRAINT [FK_FactStayNight_StayDate] FOREIGN KEY ([StayDateKey]) REFERENCES [dw].[DimDate] ([DateKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactStayNight]
    ADD CONSTRAINT [PK_FactStayNight] PRIMARY KEY NONCLUSTERED ([StayNightID] ASC) NOT ENFORCED;


GO

CREATE TABLE [dw].[FactGuestSatisfaction] (
    [SurveyID]          BIGINT         NOT NULL,
    [StayDateKey]       INT            NOT NULL,
    [SurveyDateKey]     INT            NOT NULL,
    [PropertyKey]       BIGINT         NOT NULL,
    [GuestKey]          BIGINT         NOT NULL,
    [ChannelKey]        BIGINT         NOT NULL,
    [SatisfactionScore] DECIMAL (5, 2) NOT NULL,
    [ServiceScore]      DECIMAL (5, 2) NOT NULL,
    [CleanlinessScore]  DECIMAL (5, 2) NOT NULL,
    [ValueScore]        DECIMAL (5, 2) NOT NULL,
    [WouldRecommend]    BIT            NOT NULL,
    [SourceUpdatedAt]   DATETIME2 (3)  NULL
);


GO

ALTER TABLE [dw].[FactGuestSatisfaction]
    ADD CONSTRAINT [FK_FactGuestSatisfaction_Channel] FOREIGN KEY ([ChannelKey]) REFERENCES [dw].[DimChannel] ([ChannelKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactGuestSatisfaction]
    ADD CONSTRAINT [FK_FactGuestSatisfaction_Guest] FOREIGN KEY ([GuestKey]) REFERENCES [dw].[DimGuest] ([GuestKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactGuestSatisfaction]
    ADD CONSTRAINT [FK_FactGuestSatisfaction_Property] FOREIGN KEY ([PropertyKey]) REFERENCES [dw].[DimProperty] ([PropertyKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactGuestSatisfaction]
    ADD CONSTRAINT [FK_FactGuestSatisfaction_StayDate] FOREIGN KEY ([StayDateKey]) REFERENCES [dw].[DimDate] ([DateKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactGuestSatisfaction]
    ADD CONSTRAINT [FK_FactGuestSatisfaction_SurveyDate] FOREIGN KEY ([SurveyDateKey]) REFERENCES [dw].[DimDate] ([DateKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactGuestSatisfaction]
    ADD CONSTRAINT [PK_FactGuestSatisfaction] PRIMARY KEY NONCLUSTERED ([SurveyID] ASC) NOT ENFORCED;


GO

CREATE TABLE [dw].[FactPropertyBudget] (
    [PropertyBudgetKey]  BIGINT          IDENTITY NOT NULL,
    [PropertyKey]        BIGINT          NOT NULL,
    [BudgetMonthDateKey] INT             NOT NULL,
    [BudgetRevenue]      DECIMAL (18, 2) NOT NULL,
    [BudgetOccupancyPct] DECIMAL (9, 4)  NOT NULL,
    [SourceUpdatedAt]    DATETIME2 (3)   NULL
);


GO

ALTER TABLE [dw].[FactPropertyBudget]
    ADD CONSTRAINT [FK_FactPropertyBudget_Date] FOREIGN KEY ([BudgetMonthDateKey]) REFERENCES [dw].[DimDate] ([DateKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactPropertyBudget]
    ADD CONSTRAINT [FK_FactPropertyBudget_Property] FOREIGN KEY ([PropertyKey]) REFERENCES [dw].[DimProperty] ([PropertyKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactPropertyBudget]
    ADD CONSTRAINT [PK_FactPropertyBudget] PRIMARY KEY NONCLUSTERED ([PropertyBudgetKey] ASC) NOT ENFORCED;


GO

CREATE TABLE [dw].[FactPropertyInventory] (
    [PropertyInventoryID] BIGINT        NOT NULL,
    [DateKey]             INT           NOT NULL,
    [PropertyKey]         BIGINT        NOT NULL,
    [RoomCapacity]        INT           NOT NULL,
    [RoomsOutOfService]   INT           NOT NULL,
    [RoomsSellable]       INT           NOT NULL,
    [SourceUpdatedAt]     DATETIME2 (3) NULL
);


GO

ALTER TABLE [dw].[FactPropertyInventory]
    ADD CONSTRAINT [FK_FactPropertyInventory_Date] FOREIGN KEY ([DateKey]) REFERENCES [dw].[DimDate] ([DateKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactPropertyInventory]
    ADD CONSTRAINT [FK_FactPropertyInventory_Property] FOREIGN KEY ([PropertyKey]) REFERENCES [dw].[DimProperty] ([PropertyKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactPropertyInventory]
    ADD CONSTRAINT [PK_FactPropertyInventory] PRIMARY KEY NONCLUSTERED ([PropertyInventoryID] ASC) NOT ENFORCED;


GO

CREATE TABLE [dw].[FactPropertyEvent] (
    [PropertyEventKey] BIGINT        IDENTITY NOT NULL,
    [EventID]          VARCHAR (50)  NOT NULL,
    [PropertyKey]      BIGINT        NOT NULL,
    [EventDateKey]     INT           NOT NULL,
    [EventTimestamp]   DATETIME2 (3) NOT NULL,
    [EventType]        VARCHAR (100) NOT NULL,
    [RoomNumber]       FLOAT (53)    NULL,
    [Severity]         VARCHAR (50)  NULL,
    [Description]      VARCHAR (500) NULL,
    [SourceSystem]     VARCHAR (100) NULL
);


GO

ALTER TABLE [dw].[FactPropertyEvent]
    ADD CONSTRAINT [FK_FactPropertyEvent_EventDate] FOREIGN KEY ([EventDateKey]) REFERENCES [dw].[DimDate] ([DateKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactPropertyEvent]
    ADD CONSTRAINT [FK_FactPropertyEvent_Property] FOREIGN KEY ([PropertyKey]) REFERENCES [dw].[DimProperty] ([PropertyKey]) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactPropertyEvent]
    ADD CONSTRAINT [PK_FactPropertyEvent] PRIMARY KEY NONCLUSTERED ([PropertyEventKey] ASC) NOT ENFORCED;


GO

ALTER TABLE [dw].[FactPropertyEvent]
    ADD CONSTRAINT [UQ_FactPropertyEvent_EventID] UNIQUE NONCLUSTERED ([EventID] ASC) NOT ENFORCED;


GO
