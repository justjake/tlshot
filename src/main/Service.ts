import { WebContents } from "electron";

type ServiceEventMap = Record<string, unknown>;

interface ServiceEvent<Events extends ServiceEventMap, K extends keyof Events> {
  type: K;
  data: Events[K];
}

export type AnyServiceEvent<Events extends ServiceEventMap> = {
  [K in keyof Events]: ServiceEvent<Events, K>;
}[keyof Events];

export type ServiceListener<Events extends ServiceEventMap> = (
  event: AnyServiceEvent<Events>
) => void;

/**
 * A service is a publisher that WebContents can subscribe to.
 */
export class Service<
  /* todo: const */ ChannelName extends string,
  Events extends ServiceEventMap
> {
  private subscribers = new Set<WebContents>();
  private cleanUp: (() => void) | undefined;

  constructor(
    public readonly channelName: ChannelName,
    private readonly effect: () => () => void
  ) {}

  addSubscriber(subscriber: WebContents) {
    const shouldCreateEffect = this.subscribers.size === 0;
    this.subscribers.add(subscriber);
    subscriber.once("destroyed", () => this.subscribers.delete(subscriber));
    if (shouldCreateEffect) {
      if (this.cleanUp) {
        this.cleanUp();
      }
      this.cleanUp = this.effect();
    }
  }

  removeSubscriber(subscriber: WebContents) {
    const hadSubscribers = this.subscribers.size > 0;
    this.subscribers.delete(subscriber);
    if (hadSubscribers && this.subscribers.size === 0) {
      if (this.cleanUp) {
        this.cleanUp();
        this.cleanUp = undefined;
      }
    }
  }

  emit<K extends keyof Events>(
    event: ServiceEvent<Events, K>,
    subscribers: Iterable<WebContents> = this.subscribers
  ) {
    for (const subscriber of subscribers) {
      subscriber.send(this.channelName, event);
    }
  }
}
